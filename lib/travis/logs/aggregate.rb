# frozen_string_literal: true

require 'travis/logs'
require 'travis/exceptions'
require 'travis/metrics'

module Travis
  module Logs
    class Aggregate
      def setup
        Travis.logger.info('Starting Logs Aggregation')
        Travis::Metrics.setup(Travis.config.metrics, Travis.logger)
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
          rescue StandardError => e
            Travis.logger.error(
              e.message, backtrace: e.backtrace.join("\n")
            )
          end
        end
      end

      def aggregate_logs
        lock.exclusive do
          begin
            aggregator.run
          rescue StandardError => e
            Travis::Exceptions.handle(e)
          end
        end
      end

      private def aggregator
        @aggregator ||= Travis::Logs::Services::AggregateLogs.new
      end

      private def sleep_interval
        Travis.config.logs.intervals.aggregate
      end

      private def lock
        @lock ||= Travis::Logs::Lock.new('logs.aggregate')
      end
    end
  end
end
