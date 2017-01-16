require 'pusher'
require 'multi_json'

module Travis
  module Logs
    module Helpers
      # Helper class for Pusher calls
      #
      # This class handles pushing job payloads to Pusher.
      class Pusher
        def initialize(pusher_client = nil)
          @pusher_client = pusher_client || default_client
        end

        def push(payload)
          pusher_channel(payload).trigger('job:log', pusher_payload(payload))
        end

        def pusher_channel_name(payload)
          channel = ''
          channel << 'private-' if Logs.config.pusher.secure
          channel << "job-#{payload['id']}"
          channel
        end

        def webhook(request)
          @pusher_client.webhook(request)
        end

        private

        def pusher_channel(payload)
          @pusher_client[pusher_channel_name(payload)]
        end

        def pusher_payload(payload)
          MultiJson.dump({
            'id' => payload['id'],
            '_log' => payload['chars'],
            'number' => payload['number'],
            'final' => payload['final']
          })
        end

        def default_client
          ::Pusher::Client.new(Travis::Logs.config.pusher.to_h)
        end
      end
    end
  end
end
