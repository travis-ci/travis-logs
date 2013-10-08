require 'travis/logs'
require 'travis/support'
require 'travis/logs/helpers/database'
require 'travis/logs/helpers/reporting'
require 'travis/logs/sidekiq'
require 'travis/support/exceptions/reporter'
require 'travis/logs/services/aggregate_logs'
require 'core_ext/kernel/run_periodically'
require 'active_support/core_ext/logger'

module Travis
  module Logs
    class Aggregate
      def setup
        Travis.logger.info('** Starting Logs Aggregation **')
        Travis::Logs::Helpers::Reporting.setup
        Travis::Exceptions::Reporter.start
        Travis::Logs::Sidekiq.setup

        db = Travis::Logs::Helpers::Database.connect
        Logs.database_connection = db
        Travis::Logs::Services::AggregateLogs.prepare(db)
      end

      def run
        run_periodically(Travis.config.logs.intervals.vacuum) do
          aggregate_logs
        end.join
      end

      def aggregate_logs
        Travis::Logs::Services::AggregateLogs.run
      rescue Exception => e
        Travis::Exceptions.handle(e)
      end
    end
  end
end
