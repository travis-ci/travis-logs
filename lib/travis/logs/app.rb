require 'json'
require 'sinatra'
require 'logger'

require 'travis/logs'
require 'travis/logs/existence'
require 'rack/ssl'

module Travis
  module Logs
    class App < Sinatra::Base
      attr_reader :existence, :pusher

      configure(:production, :staging) do
        use Rack::SSL
      end

      def initialize(existence = nil, pusher = nil)
        super()
        @existence = existence || Travis::Logs::Existence.new
        @pusher    = pusher    || ::Pusher::Client.new(Travis::Logs.config.pusher)
      end

      post '/pusher/existence' do
        webhook = pusher.webhook(request)
        if webhook.valid?
          webhook.events.each do |event|
            case event["name"]
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

      get "/uptime" do
        status 204
      end
    end
  end
end
