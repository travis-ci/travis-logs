logs: ./bin/receive_logs
logs1: LOGS_QUEUE=1 ./bin/receive_logs
logs2: LOGS_QUEUE=2 ./bin/receive_logs
logs3: LOGS_QUEUE=3 ./bin/receive_logs
logs4: LOGS_QUEUE=4 ./bin/receive_logs
logs5: LOGS_QUEUE=5 ./bin/receive_logs
aggregate: ./bin/aggregate_logs
archive: bundle exec sidekiq -q archive_past -c 15 -r ./lib/travis/logs/sidekiq/archive.rb
