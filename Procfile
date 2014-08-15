logs: ./bin/receive_logs
aggregate: ./bin/aggregate_logs
archive: bundle exec sidekiq -q archive -c 5 -r ./lib/travis/logs/initializers/sidekiq.rb
purge: bundle exec sidekiq -q purge_log -c 20 -r ./lib/travis/logs/initializers/sidekiq.rb
web: script/server
