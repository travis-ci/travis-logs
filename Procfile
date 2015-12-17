logs: bundle exec je ./bin/receive_logs
aggregate: bundle exec je ./bin/aggregate_logs
archive: bundle exec je sidekiq -q archive -c ${TRAVIS_LOGS_ARCHIVE_THREADS:-5} -r ./lib/travis/logs/initializers/sidekiq.rb
purge: bundle exec je sidekiq -q purge_log -c ${TRAVIS_LOGS_PURGE_THREADS:-20} -r ./lib/travis/logs/initializers/sidekiq.rb
web: bundle exec je puma -p $PORT -t ${PUMA_MIN_THREADS:-8}:${PUMA_MAX_THREADS:-12}
