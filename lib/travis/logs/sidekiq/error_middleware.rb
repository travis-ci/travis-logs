# frozen_string_literal: true

require 'pg'

require 'travis/logs'

module Travis
  module Logs
    module Sidekiq
      class ErrorMiddleware
        def initialize(pause_time: 3.seconds)
          @pause_time = pause_time
        end

        attr_reader :pause_time
        private :pause_time

        def call(worker, _msg, queue)
          yield
        rescue Travis::Logs::UnderMaintenanceError => e
          Travis.logger.warn(
            'rescued maintenance error',
            worker: worker,
            queue: queue,
            maintenance_ttl: e.ttl
          )
          sleep(pause_time)
          retry
        rescue PG::ConnectionBad => e
          Travis.logger.warn(
            'rescued bad postgres connection',
            worker: worker,
            queue: queue
          )
          sleep(pause_time)
          retry
        end
      end
    end
  end
end
