aggregate: bin/travis-logs-sidekiq aggregate ${TRAVIS_LOGS_AGGREGATE_CONCURRENCY:-5}
aggregate_sweeper: bundle exec je bin/travis-logs-aggregate-sweeper
archive: bin/travis-logs-sidekiq archive ${TRAVIS_LOGS_ARCHIVE_CONCURRENCY:-5}
drain: bundle exec je bin/travis-logs-drain
logs: bin/travis-logs-sidekiq log_parts ${TRAVIS_LOGS_LOG_PARTS_CONCURRENCY:-5}
purge: bin/travis-logs-sidekiq purge_log ${TRAVIS_LOGS_PURGE_CONCURRENCY:-5}
web: bin/travis-logs-server
