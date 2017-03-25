require 'json'
require 'jwt'
require 'pusher'
require 'rack/ssl'
require 'raven'
require 'sinatra/base'
require 'sinatra/json'
require 'sinatra/param'

require 'travis/logs'
require 'travis/logs/existence'
require 'travis/logs/helpers/metrics_middleware'
require 'travis/logs/helpers/pusher'
require 'travis/logs/services/fetch_log'
require 'travis/logs/services/fetch_log_parts'
require 'travis/logs/services/process_log_part'
require 'travis/logs/services/upsert_log'
require 'travis/logs/sidekiq'

module Travis
  module Logs
    class SentryMiddleware < Sinatra::Base
      configure do
        Raven.configure { |c| c.tags = { environment: environment } }
        use Raven::Rack
      end
    end

    class App < Sinatra::Base
      helpers Sinatra::Param

      configure(:production, :staging) do
        use Rack::SSL
        use Travis::Logs::Helpers::MetricsMiddleware
      end

      configure do
        enable :logging if Travis::Logs.config.logs.api_logging?
        use SentryMiddleware if ENV['SENTRY_DSN']
      end

      def initialize(auth_token: ENV['AUTH_TOKEN'].to_s,
                     rsa_public_key_string: ENV['JWT_RSA_PUBLIC_KEY'].to_s)
        super

        @auth_token = auth_token.strip
        @boot_time = Time.now.utc.freeze

        unless rsa_public_key_string.strip.empty?
          @rsa_public_key = OpenSSL::PKey::RSA.new(rsa_public_key_string)
        end

        setup
      end

      attr_reader :auth_token, :rsa_public_key, :boot_time
      private :auth_token
      private :rsa_public_key
      private :boot_time

      post '/pusher/existence' do
        webhook = pusher.webhook(request)
        if webhook.valid?
          webhook.events.each do |event|
            case event['name']
            when 'channel_occupied'
              existence.occupied!(event['channel'])
            when 'channel_vacated'
              existence.vacant!(event['channel'])
            end
          end

          status 204
          body nil
        else
          status 401
        end
      end

      get '/uptime' do
        json uptime: Time.now.utc - boot_time,
             greeting: 'hello, human 👋!',
             pong: redis_ping,
             now: database.now,
             version: Travis::Logs.version
      end

      put '/logs/:job_id' do
        halt 500, 'authentication token is not set' if auth_token.empty?
        halt 403 unless authorized?(request)

        request.body.rewind
        content = request.body.read
        content = nil if content.empty?
        removed_by = (Integer(params[:removed_by]) if params[:removed_by])

        results = upsert_log_service.run(
          job_id: Integer(params[:job_id]),
          content: content,
          removed_by: removed_by
        )

        halt 404 if results.nil? || results.empty?
        content_type :json, charset: 'utf-8'
        status 200
        json results.first.merge(:@type => 'log')
      end

      post '/logs/multi' do
        halt 500, 'authentication token is not set' if auth_token.empty?
        halt 403 unless authorized?(request)

        request.body.rewind

        items = Array(JSON.parse(request.body.read))
        halt 400 unless all_items_valid?(items)

        database.transaction do
          items.each do |item|
            removed_by = (Integer(item['removed_by']) if item['removed_by'])
            upsert_log_service.run(
              job_id: Integer(item.fetch('job_id')),
              content: item.fetch('content', ''),
              removed_by: removed_by
            )
          end
        end

        status 204
        body nil
      end

      get '/log-parts/:job_id' do
        halt 500, 'authentication token is not set' if auth_token.empty?
        halt 403 unless authorized?(request)

        param :job_id, Integer
        param :part_numbers, Array, default: []
        param :after, Integer

        results = fetch_log_parts_service.run(
          job_id: params[:job_id],
          after: params[:after],
          part_numbers: params[:part_numbers].map { |i| Integer(i) }
        )
        halt 404 if results.nil?
        content_type :json, charset: 'utf-8'
        status 200
        json :@type => 'log_parts',
             log_parts: results,
             job_id: params[:job_id]
      end

      put '/log-parts/:job_id/:log_part_id' do
        auth_header = request.env['HTTP_AUTHORIZATION']
        halt 403 if auth_header.nil?

        if auth_header.start_with?('Bearer ')
          halt 500, 'key is not set' if rsa_public_key.nil?
          Travis.uuid = request.env['HTTP_X_REQUEST_ID']
          begin
            JWT.decode(auth_header[7..-1], rsa_public_key, true, algorithm: 'RS512', verify_sub: true, 'sub' => params[:job_id])
          rescue JWT::DecodeError
            halt 403
          end
        elsif auth_header.start_with?('token ')
          halt 500, 'authentication token is not set' if auth_token.empty?
          halt 403 unless authorized?(request)
        else
          halt 403
        end

        data = JSON.parse(request.body.read)
        if data['@type'] != 'log_part'
          halt 400, JSON.dump('error' => '@type should be log_part')
        end

        content = case data['encoding']
                  when 'base64'
                    Base64.decode64(data['content'])
                  else
                    halt 400, JSON.dump('error' => 'invalid encoding, only base64 supported')
                  end

        process_log_part_service.run(
          'id' => Integer(params[:job_id]),
          'log' => content,
          # NOTE: `log_part_id` is *not* cast via Integer because it may be a
          # string `"last"`.
          'number' => params[:log_part_id],
          'final' => data['final']
        )

        status 204
      end

      put '/logs/:job_id/archived' do
        halt 500, 'authentication token is not set' if auth_token.empty?
        halt 403 unless authorized?(request)

        halt 501
      end

      get '/logs/:id' do
        halt 500, 'authentication token is not set' if auth_token.empty?
        halt 403 unless authorized?(request)

        result = fetch_log_service.run(
          (params[:by] || :job_id).to_sym => Integer(params[:id])
        )
        halt 404 if result.nil?
        content_type :json, charset: 'utf-8'
        status 200
        json result.merge(:@type => 'log')
      end

      get '/logs/:job_id/id' do
        halt 500, 'authentication token is not set' if auth_token.empty?
        halt 403 unless authorized?(request)

        result = database.log_id_for_job_id(Integer(params[:job_id]))
        halt 404 if result.nil?
        content_type :json, charset: 'utf-8'
        status 200
        json id: result, :@type => 'log'
      end

      private def authorized?(request)
        Rack::Utils.secure_compare(
          request.env['HTTP_AUTHORIZATION'].to_s,
          "token #{auth_token}"
        )
      end

      private def fetch_log_service
        @fetch_log_service ||= Travis::Logs::Services::FetchLog.new(
          database: database
        )
      end

      private def fetch_log_parts_service
        @fetch_log_parts_service ||= Travis::Logs::Services::FetchLogParts.new(
          database: database
        )
      end

      private def upsert_log_service
        @upsert_log_service ||= Travis::Logs::Services::UpsertLog.new(
          database: database
        )
      end

      private def process_log_part_service
        @process_log_part_service ||=
          Travis::Logs::Services::ProcessLogPart.new(
            database: database,
            pusher_client: pusher,
            existence: existence
          )
      end

      private def existence
        @existence ||= Travis::Logs::Existence.new
      end

      private def pusher
        @pusher ||= Travis::Logs::Helpers::Pusher.new
      end

      private def database
        @database ||= Travis::Logs.database_connection
      end

      private def setup
        Travis::Metrics.setup
        Travis::Logs::Sidekiq.setup
      end

      private def redis_ping
        Travis::Logs.redis_pool.with { |conn| conn.ping.to_s }
      end

      private def all_items_valid?(items)
        items.all? do |item|
          item.key?('job_id') && item['job_id'].to_s =~ /^[0-9]+$/
        end
      end
    end
  end
end
