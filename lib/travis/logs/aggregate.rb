require 'travis/logs'
require 'travis/support'
require 'travis/support/database'
require 'travis/support/exceptions/reporter'
require 'travis/support/log_subscriber/active_record_metrics'
require 'travis/support/memory'
require 'travis/logs/services/aggregate_logs'
require 'core_ext/kernel/run_periodically'

module Travis
  module Logs
    class Aggregate
      def setup
        Travis::Database.connect
        Travis::Exceptions::Reporter.start
        Travis::Logs::Sidekiq.setup
        Travis::LogSubscriber::ActiveRecordMetrics.attach
        Travis::Memory.new(:logs).report_periodically if Travis.env == 'production'
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
