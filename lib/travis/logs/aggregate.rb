require 'travis'
require 'travis/support'
require 'core_ext/kernel/run_periodically'

module Travis
  module Logs
    class Aggregate
      def setup
        Travis::Database.connect
        Travis::Features.start
        Travis::Notification.setup
        Travis::Exceptions::Reporter.start

        Travis::Async.enabled = true
        Travis::Async::Sidekiq.setup(Travis.config.redis.url, Travis.config.sidekiq)

        instrumenter = Travis.env == 'production' ? Travis::Instrumentation : Travis::Notification
        instrumenter.setup
      end

      def run
        run_periodically(Travis.config.logs.intervals.vacuum || 10) do
          aggregate_logs if Travis::Features.feature_active?(:log_aggregation)
        end.join
      end

      def aggregate_logs
        Travis.run_service(:logs_aggregate)
      rescue Exception => e
        Travis::Exceptions.handle(e)
      end
    end
  end
end
