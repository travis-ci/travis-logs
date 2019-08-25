# frozen_string_literal: true

require 'travis/logs'
require 'travis/exceptions'

module Travis
  module Logs
    class SendTimings
      def setup
        Travis.logger.info('Starting Timing Sender')
        Travis::Logs::Sidekiq.setup
      end

      def run
        loop do
          parse_logs
          sleep sleep_interval
        end
      end

      def parse_logs
        lock.exclusive do
          begin
            send_timings_service.run
          rescue StandardError => e
            Travis::Exceptions.handle e
          end
        end
      end

      private def send_timings_service
        @send_timings_service ||= Travis::Logs::Services::SendTimings.new
      end

      private def sleep_interval
        Travis.config.logs.intervals.send_timings
      end

      private def lock
        @lock ||= Travis::Logs::Lock.new('logs.send_timings')
      end
    end
  end
end
