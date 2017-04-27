aggregate_sweeper: bundle exec je bin/travis-logs-aggregate-sweeper
drain: bundle exec je bin/travis-logs-drain
web: bin/travis-logs-server
worker_high: bin/travis-logs-sidekiq -c ${TRAVIS_LOGS_WORKER_HIGH_CONCURRENCY:-5} -q aggregate,1 -q logs,1
logs: bin/travis-logs-sidekiq -c ${TRAIS_LOGS_LOG_PARTS_CONCURRENCY:-5} -q logs
worker_low: bin/travis-logs-sidekiq -c ${TRAVIS_LOGS_WORKER_LOW_CONCURRENCY:-5} -q archive,1 -q maintenance,1 -q purge_log,1

console: bundle exec je script/console
config: bundle exec je bin/travis-logs-config
