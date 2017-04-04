# Planning `pg_partman` usage

Official docs available
[here](https://github.com/keithf4/pg_partman/tree/master/doc).

## Expected steps

The below steps specify travis-ci.org production applications. The same or
similar process _should_ work for travis-ci.com.

### preparation

- Get PostgreSQL 9.6 upgrade timing from a forked version
- Announce maintenance window at least 2d ahead of time

### create gap in `log_parts` table

- `heroku ps:scale scheduler=0 -a travis-scheduler-production`
- Disable termination on all ASGs
- Wait up to 50m for current jobs to complete
- `heroku ps:scale logs=0 -a travis-logs-production`
- `heroku ps:scale scheduler=2 -a travis-scheduler-production`
- Wait for log parts aggregation to complete

### upgrade and set up partitioning

- `heroku ps:scale aggregate=0 aggregate_sweeper=0 archive=0 logs=0 purge=0 receiver=0 web=0 -a travis-logs-production`
- `heroku pg:upgrade LOGS_READONLY_DATABASE -a travis-logs-production`
- `heroku pg:wait -a travis-logs-production`
- `heroku pg:promote LOGS_READONLY_DATABASE -a travis-logs-production`
- On the newly promoted database, run `TRUNCATE TABLE log_parts`
- Attach the newly promoted database as `LOGS_DATABASE` to `travis-logs-production`
- `sqitch deploy "db:pg:$(heroku config:get LOGS_DATABASE_URL -a travis-logs-production | sed 's,postgres:,,')"`
- Attach the newly promoted database as `LOGS_DATABASE` to
  `travis-api-production`, `travis-gatekeeper-production`,
`travis-hub-production`, and `travis-production`

### set up maintenance task

- `heroku addons:create scheduler:standard -a travis-logs-production`
- Configure the scheduler addon to run daily:

``` bash
psql -d "${LOGS_DATABASE_URL}" -c "SELECT partman.run_maintenance('public.log_parts');"
```

### resume all dynos

``` bash
heroku ps:scale \
  logs=5:Performance-M \
  aggregate=1:Performance-M \
  archive=1:Standard-2X \
  purge=1:Standard-2X \
  web=2:Standard-2X \
  receiver=2:Standard-2X \
  -a travis-logs-production`
```
