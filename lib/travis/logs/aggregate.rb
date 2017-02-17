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
          aggregate_logs
          break if run_once?
          sleep sleep_interval
        end
      end

      def aggregate_logs(log_part_id_range = default_log_part_id_range)
        aggregator.run(log_part_id_range)
      rescue Exception => e
        Travis::Exceptions.handle(e)
      end

      private def aggregator
        @aggregator ||= Travis::Logs::Services::AggregateLogs.new
      end

      private def sleep_interval
        Travis.config.logs.intervals.vacuum
      end

      private def default_log_part_id_range
        return nil unless ENV.key?('TRAVIS_LOGS_LOG_PART_ID_RANGE')
        @log_part_id_range ||= ENV.fetch(
          'TRAVIS_LOGS_LOG_PART_ID_RANGE', ''
        ).split('-', 2)
      end

      private def run_once?
        %w(yes on 1).include?(
          ENV['TRAVIS_LOGS_AGGREGATE_ONCE'] ||
          ENV['AGGREGATE_ONCE'] ||
          'off'
        )
      end
    end
  end
end
