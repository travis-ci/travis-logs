aggregate: bundle exec je sidekiq -q aggregate -c ${TRAVIS_LOGS_AGGREGATE_CONCURRENCY:-5} -r ./lib/travis/logs/initializers/sidekiq.rb
aggregate_sweeper: bundle exec je script/aggregate-sweeper
archive: bundle exec je sidekiq -q archive -c ${TRAVIS_LOGS_ARCHIVE_CONCURRENCY:-5} -r ./lib/travis/logs/initializers/sidekiq.rb
logs: bundle exec je sidekiq -q log_parts -c ${TRAVIS_LOGS_LOG_PARTS_CONCURRENCY:-5} -r ./lib/travis/logs/initializers/sidekiq.rb
purge: bundle exec je sidekiq -q purge_log -c ${TRAVIS_LOGS_PURGE_CONCURRENCY:-5} -r ./lib/travis/logs/initializers/sidekiq.rb
receiver: bundle exec je script/receiver
web: script/server
