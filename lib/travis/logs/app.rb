require 'json'
require 'sinatra'

require 'travis/logs/existence'

module Travis
  module Logs
    class App < Sinatra::Base
      attr_reader :existence, :pusher

      def initialize(app = nil, existence = nil, pusher = nil)
        super(app)
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
    end
  end
end
