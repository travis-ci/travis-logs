logs: ./bin/receive_logs
aggregate: ./bin/aggregate_logs

archive: bundle exec sidekiq -q archive_past -c 25 -r ./lib/travis/logs/sidekiq/archive.rb
verify: ./script/verify
vacuum: ./script/vacuum --from 0 --to 3280461
