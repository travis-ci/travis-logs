# frozen_string_literal: true

require 'digest/sha1'

require 'jwt'
require 'multi_json'
require 'pusher'
require 'rack/ssl'
require 'raven'
require 'sinatra/base'
require 'sinatra/json'
require 'sinatra/param'

require 'travis/logs'
require 'travis/metrics'

require 'travis/logs/app/opencensus'

module Travis
  module Logs
    class App < Sinatra::Base
      helpers Sinatra::Param

      configure(:production, :staging) do
        disable :dump_errors
        use Rack::SSL unless Travis.config.logs.disable_ssl?
        use Travis::Logs::MetricsMiddleware
        use Raven::Rack
        use Travis::Logs::OpenCensus if Travis::Logs::OpenCensus.enabled?
      end

      configure do
        enable :logging if Travis.config.logs.api_logging?
      end

      def initialize(auth_token: ENV['AUTH_TOKEN'].to_s,
                     rsa_public_key_string: ENV['JWT_RSA_PUBLIC_KEY'].to_s)
        super

        @auth_token = auth_token.strip
        @boot_time = Time.now.utc.freeze

        @rsa_public_key = OpenSSL::PKey::RSA.new(rsa_public_key_string) unless rsa_public_key_string.strip.empty?

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

        items = Array(MultiJson.load(request.body.read))
        halt 400 unless all_logs_valid?(items)

        database.db.transaction do
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
        halt 503 if maint.enabled?

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
        assert_log_parts_authorized!

        request.body.rewind
        data = MultiJson.load(request.body.read)
        halt 400, MultiJson.dump(error: '@type should be log_part') if data['@type'] != 'log_part'

        halt 400, MultiJson.dump(error: 'invalid encoding') if data['encoding'] != 'base64'

        payload = {
          'encoding' => 'base64',
          'final' => data['final'],
          'id' => Integer(params[:job_id]),
          'log' => data['content'],
          'number' => params[:log_part_id] # NOTE: `log_part_id` may be "last"
        }

        Travis::Logs::Sidekiq::PusherForwarding.perform_async(payload)
        Travis::Logs::Sidekiq::LogParts.perform_async(payload)

        status 204
        body nil
      end

      post '/log-parts/multi' do
        assert_log_parts_authorized!

        request.body.rewind
        log_parts = Array(MultiJson.load(request.body.read))
        halt 400 unless all_log_parts_valid?(log_parts)

        payloads = []

        log_parts.each do |log_part|
          unless jwt_decode?(log_part['tok'].to_s, log_part['job_id'].to_s)
            Travis.logger.warn('discarding unauthorized log part',
                               job_id: log_part['job_id'])
            next
          end

          payloads << {
            'encoding' => 'base64',
            'id' => Integer(log_part['job_id']),
            'log' => log_part['content'],
            'number' => log_part['number'],
            'final' => log_part['final']
          }
        end

        payloads.each do |payload|
          Travis::Logs::Sidekiq::PusherForwarding.perform_async(payload)
        end

        Travis.logger.debug(
          'sending payload',
          len: payloads.length,
          to: Travis::Logs::Sidekiq::LogParts.to_s
        )
        Travis::Logs::Sidekiq::LogParts.perform_async(payloads)

        status 204
        body nil
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

        result = database.cached_log_id_for_job_id(
          Integer(params[:job_id])
        )

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

      private def existence
        @existence ||= Travis::Logs::Existence.new
      end

      private def pusher
        @pusher ||= Travis::Logs::Pusher.new
      end

      private def database
        @database ||= Travis::Logs.database_connection
      end

      private def maint
        @maint ||= Travis::Logs::Maintenance.new
      end

      private def setup
        Travis::Metrics.setup(Travis.config.metrics, Travis.logger)
        Travis::Logs::Sidekiq.setup
        Travis::Logs::OpenCensus.setup
      end

      private def redis_ping
        Travis::Logs.redis.ping.to_s
      end

      private def assert_log_parts_authorized!
        auth_header = request.env['HTTP_AUTHORIZATION']
        halt 403 if auth_header.nil?
        halt 503 if maint.enabled?
        case auth_header
        when /^Bearer / then assert_bearer_authorized!(auth_header)
        when /^token sig:/ then assert_log_parts_multi_payload_authorized!(
          request, auth_header
        )
        when /^token / then assert_token_authorized!(request)
        else
          halt 403
        end
      end

      private def assert_bearer_authorized!(auth_header)
        halt 500, 'key is not set' if rsa_public_key.nil?
        Thread.current[:uuid] = request.env['HTTP_X_REQUEST_ID']
        halt 403 unless jwt_decode?(auth_header[7..-1], params[:job_id])
      end

      private def assert_log_parts_multi_payload_authorized!(
        request, auth_header
      )
        # NOTE: This authorization check is little more than a signature
        # verification, and the signature is not a security mechanism.  The
        # decision regarding whether a given log part will be accepted is
        # performed later on.
        halt 403 unless log_parts_multi_payload_authorized?(
          request, auth_header
        )
      end

      private def assert_token_authorized!(request)
        halt 500, 'authentication token is not set' if auth_token.empty?
        halt 403 unless authorized?(request)
      end

      private def log_parts_multi_payload_authorized?(request, auth_header)
        request.body.rewind
        tokens = Array(
          MultiJson.load(request.body.read)
        ).map { |i| i['tok'].to_s }
        Rack::Utils.secure_compare(
          auth_header,
          "token sig:#{Digest::SHA1.hexdigest(tokens.join)}"
        )
      end

      private def all_logs_valid?(items)
        items.all? do |item|
          item.key?('job_id') && item['job_id'].to_s =~ /^[0-9]+$/
        end
      end

      private def all_log_parts_valid?(items)
        items.all? do |item|
          item.key?('@type') && item['@type'] == 'log_part' &&
            item.key?('encoding') && item['encoding'] == 'base64' &&
            item.key?('job_id') && item['job_id'].to_s =~ /^[0-9]+$/ &&
            item.key?('number') && item['number'].to_s =~ /^([0-9]+|last)$/
        end
      end

      private def jwt_decode?(encoded_jwt, job_id)
        JWT.decode(
          encoded_jwt,
          rsa_public_key,
          true,
          algorithm: 'RS512',
          verify_sub: true,
          sub: job_id
        )
        true
      rescue JWT::InvalidSubError
        false
      rescue JWT::DecodeError
        false
      end
    end
  end
end
