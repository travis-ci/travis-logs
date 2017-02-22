logs: ./bin/receive_logs
web: ./script/server
aggregate_sweeper: ./bin/aggregate_logs
aggregate: bundle exec sidekiq -q aggregate -c ${TRAVIS_LOGS_AGGREGATE_CONCURRENCY:-5} -r ./lib/travis/logs/initializers/sidekiq.rb
archive: bundle exec sidekiq -q archive -c ${TRAVIS_LOGS_ARCHIVE_CONCURRENCY:-5} -r ./lib/travis/logs/initializers/sidekiq.rb
purge: bundle exec sidekiq -q purge_log -c ${TRAVIS_LOGS_PURGE_CONCURRENCY:-20} -r ./lib/travis/logs/initializers/sidekiq.rb
