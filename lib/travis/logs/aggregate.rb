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
        Travis.logger.info('** Starting Logs Aggregation **')
        Travis::Metrics.setup
        Travis::Logs::Sidekiq.setup
        Logs.database_connection = Travis::Logs::Helpers::Database.connect
      end

      def run
        loop do
          aggregate_logs
          sleep Travis.config.logs.intervals.vacuum
        end
      end

      def aggregate_logs
        Travis::Logs::Services::AggregateLogs.run
      rescue Exception => e
        Travis::Exceptions.handle(e)
      end
    end
  end
end
