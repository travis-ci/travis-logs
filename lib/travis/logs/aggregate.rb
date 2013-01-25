require 'travis'
require 'travis/support'
require 'core_ext/kernel/run_periodically'

Travis::Database.connect
Travis::Features.start
Travis::Exceptions::Reporter.start

Travis::Async.enabled = true
Travis::Async::Sidekiq.setup(Travis.config.redis.url, Travis.config.sidekiq)

instrumenter = Travis.env == 'production' ? Travis::Instrumentation : Travis::Notification
instrumenter.setup

def aggregate_logs
  Travis.run_service(:logs_aggregate)
rescue Exception => e
  Travis::Exceptions.handle(e)
end

run_periodically(Travis.config.logs.intervals.vacuum || 10) do
  aggregate_logs if Travis::Features.feature_active?(:log_aggregation)
end.join
