require "pusher"

module Travis
  module Logs
    module Helpers
      # Helper class for Pusher calls
      #
      # This class handles pushing job payloads to Pusher.
      class Pusher
        def initialize(pusher_client = Travis::Logs.config.pusher_client)
          @pusher_client = pusher_client
        end

        def push(payload)
          pusher_channel(payload).trigger("job:log", pusher_payload(payload))
        end

        private

        def pusher_channel(payload)
          @pusher_client[pusher_channel_name(payload)]
        end

        def pusher_channel_name(payload)
          channel = ""
          channel << "private-" if Logs.config.pusher.secure
          channel << "job-#{payload["id"]}"
          channel
        end

        def pusher_payload(payload)
          {
            "id" => payload["id"],
            "_log" => payload["chars"],
            "number" => payload["number"],
            "final" => payload["final"],
          }
        end
      end
    end
  end
end
