require 'json'
require 'raven'
require 'sinatra/base'
require 'logger'
require 'pusher'
require 'jwt'

require 'travis/logs'
require 'travis/logs/existence'
require 'travis/logs/helpers/database'
require 'rack/ssl'

module Travis
  module Logs
    class SentryMiddleware < Sinatra::Base
      configure do
        Raven.configure { |c| c.tags = { environment: environment } }
        use Raven::Rack
      end
    end

    class App < Sinatra::Base
      attr_reader :existence, :pusher, :database

      configure(:production, :staging) do
        use Rack::SSL
      end

      configure do
        use SentryMiddleware if ENV['SENTRY_DSN']
      end

      def initialize(existence = nil, pusher = nil, database = nil)
        super()
        @existence = existence || Travis::Logs::Existence.new
        @pusher    = pusher || ::Pusher::Client.new(Travis::Logs.config.pusher)
        @database  = database || Travis::Logs::Helpers::Database.connect
      end

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
        status 204
      end

      put '/logs/:job_id' do
        halt 500, 'authentication token is not set' if ENV['AUTH_TOKEN'].to_s.strip.empty?
        halt 403 if request.env['HTTP_AUTHORIZATION'] != "token #{ENV['AUTH_TOKEN']}"

        job_id = Integer(params[:job_id])

        log = database.log_for_job_id(job_id) || database.create_log(job_id)

        request.body.rewind
        database.set_log_content(log[:id], request.body.read)

        status 204
      end

      put '/log-parts/:job_id/:log_part_id' do
        Travis.uuid = request.env['HTTP_X_REQUEST_ID']

        auth_header = request.env['HTTP_AUTHORIZATION']
        if auth_header.nil? || !request.env['HTTP_AUTHORIZATION'].starts_with?('Bearer ')
          halt 403
        end

        begin
          JWT.decode(auth_header[7..-1], rsa_public_key, true, { algorithm: 'RS512', verify_sub: true, 'sub' => params[:job_id] })
        rescue JWT::DecodeError
          halt 403
        end

        data = JSON.parse(request.body.read)
        if data['@type'] != 'log_part'
          halt 400, JSON.dump({ 'error' => '@type should be log_part' })
        end

        content = case data['encoding']
        when 'base64'
          Base64.decode64(data['content']) 
        else
          halt 400, JSON.dump({ 'error' => 'invalid encoding, only base64 supported' })
        end

        Travis::Logs::Services::ProcessLogPart.run({
          'id' => Integer(params[:job_id]),
          'log' => content,
          'number' => params[:log_part_id],
          'final' => data['final'],
        })
      end
    end
  end
end
