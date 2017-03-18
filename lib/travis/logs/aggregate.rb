require 'travis/logs'
require 'travis/logs/helpers/database'
require 'travis/logs/helpers/locking'
require 'travis/logs/sidekiq'
require 'travis/support/exceptions/reporter'
require 'travis/support/metrics'
require 'travis/logs/services/aggregate_logs'
require 'active_support/core_ext/logger'

module Travis
  module Logs
    class Aggregate
      include Helpers::Locking

      def setup
        Travis.logger.info('Starting Logs Aggregation')
        Travis::Metrics.setup
        Travis::Logs::Sidekiq.setup
      end

      def run
        loop do
          aggregate_logs
          sleep sleep_interval
        end
      end

      def run_ranges
        if ENV.key?('TRAVIS_LOGS_AGGREGATE_START')
          cursor = Integer(
            ENV['TRAVIS_LOGS_AGGREGATE_START']
          )
        end
        max_id = Integer(
          ENV['TRAVIS_LOGS_AGGREGATE_MAX_ID'] || 31_116_000_000
        ) # 2017-02-19 01:31:40
        per_page = Integer(
          ENV['TRAVIS_LOGS_AGGREGATE_PER_PAGE'] || 100_000
        )

        loop do
          begin
            cursor = aggregator.run_ranges(cursor, per_page)
            break if cursor.to_i > max_id
          rescue Exception => e
            Travis.logger.error(
              e.message, backtrace: e.backtrace.join("\n")
            )
          end
        end
      end

      def aggregate_logs
        exclusive do
          begin
            aggregator.run
          rescue Exception => e
            Travis::Exceptions.handle(e)
          end
        end
      end

      private def exclusive(&block)
        super('logs.aggregate', &block)
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
