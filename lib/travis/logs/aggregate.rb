require 'travis'
require 'travis/support'
require 'core_ext/kernel/run_periodically'

Travis::Database.connect
Travis::Features.start
Travis::Exceptions::Reporter.start

def aggregate_logs
  Travis.run_service(:logs_aggregate)
rescue Exception => e
  Travis::Exceptions.handle(e)
end

run_periodically(Travis.config.logs.intervals.vacuum || 10) do
  aggregate_logs if Travis::Features.feature_active?(:log_aggregation)
end.join
