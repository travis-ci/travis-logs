logs: ./bin/receive_logs
web: ./script/server
aggregate: ./bin/aggregate_logs
aggregator: bundle exec sidekiq -q aggregate -c ${TRAVIS_LOGS_ARCHIVE_CONCURRENCY:-5} -r ./lib/travis/logs/initializers/sidekiq.rb
archive: bundle exec sidekiq -q archive -c ${TRAVIS_LOGS_ARCHIVE_CONCURRENCY:-5} -r ./lib/travis/logs/initializers/sidekiq.rb
purge: bundle exec sidekiq -q purge_log -c ${TRAVIS_LOGS_PURGE_CONCURRENCY:-20} -r ./lib/travis/logs/initializers/sidekiq.rb
