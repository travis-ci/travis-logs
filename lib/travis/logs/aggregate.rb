require 'travis/logs'
require 'travis/logs/helpers/database'
require 'travis/logs/sidekiq'
require 'travis/support/exceptions/reporter'
require 'travis/support/metrics'
require 'travis/logs/services/aggregate_logs'
require 'active_support/core_ext/logger'

module Travis
  module Logs
    class Aggregate
      def setup
        Travis.logger.info('Starting Logs Aggregation')
        Travis::Metrics.setup
        Travis::Logs::Sidekiq.setup
        Travis::Logs.database_connection = Travis::Logs::Helpers::Database.connect
      end

      def run
        loop do
          aggregate_logs(ENV.fetch('TRAVIS_LOGS_MIN_LOG_PART_ID', nil))
          sleep sleep_interval
        end
      end

      def aggregate_logs(min_log_part_id)
        aggregator.run(min_log_part_id)
      rescue Exception => e
        Travis::Exceptions.handle(e)
      end

      private def aggregator
        @aggregator ||= Travis::Logs::Services::AggregateLogs.new
      end

      private def sleep_interval
        Travis.config.logs.intervals.vacuum
      end
    end
  end
end
