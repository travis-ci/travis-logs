# frozen_string_literal: true

module Travis
  module Logs
    module Sidekiq
      class ErrorMiddleware
        def initialize(*)
          # nah
        end

        def call(worker, _msg, queue)
          yield
        rescue Travis::Logs::UnderMaintenanceError => e
          Travis.logger.warn(
            'rescued maintenance error',
            worker: worker,
            queue: queue,
            sleeping: e.ttl
          )
          sleep(e.ttl)
          retry
        end
      end
    end
  end
end
