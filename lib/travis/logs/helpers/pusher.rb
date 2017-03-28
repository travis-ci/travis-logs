# frozen_string_literal: true
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
          "#{secure? ? 'private-' : ''}job-#{payload['id']}"
        end

        def webhook(request)
          @pusher_client.webhook(request)
        end

        private def pusher_channel(payload)
          @pusher_client[pusher_channel_name(payload)]
        end

        private def pusher_payload(payload)
          MultiJson.dump('id' => payload['id'],
                         '_log' => payload['chars'],
                         'number' => payload['number'],
                         'final' => payload['final'])
        end

        private def default_client
          ::Pusher::Client.new(Travis::Logs.config.pusher.to_h)
        end

        private def secure?
          Travis::Logs.config.pusher.secure
        end
      end
    end
  end
end
