module Travis
  module Logs
    class Instrument
      class Handler < Travis::Notification::Instrument
        def log_completed
          # publish(
          #   msg: %(#{target.class.name}#log for #<Job id="#{target.payload['id']}">),
          #   event: target.event,
          #   payload: target.payload
          # )
        end
      end
    end
  end
end

