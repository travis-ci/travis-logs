require 'travis/logs'
require 'travis/support'
require 'travis/logs/helpers/database'
require 'travis/logs/sidekiq'
require 'travis/support/exceptions/reporter'
require 'travis/support/metrics'
require 'travis/logs/services/aggregate_logs'
require 'core_ext/kernel/run_periodically'
require 'active_support/core_ext/logger'

module Travis
  module Logs
    class Aggregate
      def setup
        Travis.logger.info('** Starting Logs Aggregation **')
        Travis::Metrics.setup
        Travis::Logs::Sidekiq.setup

        db = Travis::Logs::Helpers::Database.connect
        Logs.database_connection = db
        Travis::Logs::Services::AggregateLogs.prepare(db)
        :alldone
      end

      def run
        thr = run_periodically(Travis.config.logs.intervals.vacuum) do
          aggregate_logs
        end

        thr.join if thr.respond_to?(:join)

        :ran
      end

      def aggregate_logs
        Travis::Logs::Services::AggregateLogs.run
      rescue Exception => e
        Travis::Exceptions.handle(e)
      end
    end
  end
end
