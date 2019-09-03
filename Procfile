drain: bundle exec je bin/travis-logs-drain
drain_sharded: TRAVIS_LOGS_DRAIN_RABBITMQ_SHARDING=true bundle exec je bin/travis-logs-drain
web: bin/travis-logs-pgbouncer-exec bin/travis-logs-server
worker_critical: bin/travis-logs-pgbouncer-exec bin/travis-logs-sidekiq -c ${TRAVIS_LOGS_WORKER_CRITICAL_CONCURRENCY:-5} -q logs.pusher_forwarding,1
worker_high: bin/travis-logs-pgbouncer-exec bin/travis-logs-sidekiq -c ${TRAVIS_LOGS_WORKER_HIGH_CONCURRENCY:-5} -q aggregate,1 -q log_parts,1
worker_low: bin/travis-logs-sidekiq -c ${TRAVIS_LOGS_WORKER_LOW_CONCURRENCY:-5} -q archive,1 -q maintenance,1 -q purge_log,1 -q timing_info,1

aggregate_sweeper: bin/travis-logs-pgbouncer-exec bundle exec je bin/travis-logs-aggregate-sweeper

console: bundle exec je script/console
config: bundle exec je bin/travis-logs-config
