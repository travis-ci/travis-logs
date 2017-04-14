# Planning `pg_partman` usage

Official docs available
[here](https://github.com/keithf4/pg_partman/tree/master/doc).

## Expected steps

The below steps specify travis-ci.org production applications. The same or
similar process _should_ work for travis-ci.com.  This section is intended to be
copy-paste friendly for creating a maintenance issue with checklist(s).

### preparation

- [x] Get PostgreSQL 9.6 upgrade timing from a forked version
  - upgrade on travis-logs-staging: 7m20s
  - upgrade on travis-logs-production: 9h41m50s
    - ~9h37m waiting for WAL catch-up
    - ~4m for upgrade
- [x] Announce maintenance window at least 2d ahead of time (https://www.traviscistatus.com/incidents/xnw9tr0b8wwm)

### create gap in `log_parts` table

- [ ] scale down scheduler

``` bash
heroku ps:scale scheduler=0 -a travis-scheduler-production`
```

- [ ] suspend terminations on ASGs

``` bash
aws autoscaling suspend-processes \
  --auto-scaling-group-name 'production-2-workers-org' \
  --scaling-processes 'Terminate'

aws autoscaling suspend-processes \
  --auto-scaling-group-name 'precise-production-2-workers-org' \
  --scaling-processes 'Terminate'
```

- [ ] wait up to 50m for current jobs to complete
- [ ] scale down drain and log parts processing

``` bash
heroku ps:scale drain=0 logs=0 -a travis-logs-production
```

- [ ] scale up scheduler

``` bash
heroku ps:scale scheduler=2 -a travis-scheduler-production
```

- [ ] wait for log parts aggregation to complete

### upgrade and set up partitioning

- [ ] scale down all logs dynos

``` bash
heroku ps:scale \
  aggregate=0 \
  aggregate_sweeper=0 \
  archive=0 \
  logs=0 \
  purge=0 \
  drain=0 \
  web=0 \
  -a travis-logs-production
```

- [ ] perform upgrade and wait for availability

``` bash
heroku pg:upgrade LOGS_READONLY_DATABASE -a travis-logs-production

heroku pg:wait -a travis-logs-production
```

- [ ] promote upgraded database to primary

``` bash
heroku pg:promote LOGS_READONLY_DATABASE --as LOGS_DATABASE -a travis-logs-production
```

- [ ] truncate the `log_parts` table

``` bash
echo 'TRUNCATE TABLE log_parts' \
  | heroku pg:psql LOGS_DATABASE -a travis-logs-production
```

- [ ] log the initial structure migration

``` bash
sqitch deploy \
  --to-change structure \
  --log-only \
  "db:pg:$(heroku config:get LOGS_DATABASE_URL -a travis-logs-production | sed 's,postgres:,,')"
```

- [ ] apply remaining migrations, including partman installation

``` bash
sqitch deploy "db:pg:$(heroku config:get LOGS_DATABASE_URL -a travis-logs-production | sed 's,postgres:,,')"
```

- [ ] attach primary database to `travis-api-production`

``` bash
heroku addons:attach \
  "${logs_database_addon_name}" \
  --as LOGS_DATABASE \
  -a travis-api-production
```

### set up maintenance task

- [ ] create scheduler addon

``` bash
heroku addons:create scheduler:standard -a travis-logs-production
```

- [ ] configure the scheduler addon to run daily:

``` bash
psql -d "${LOGS_DATABASE_URL}" -c "SELECT partman.run_maintenance('public.log_parts');"
```

### resume stuff

- [ ] scale up all logs dynos

``` bash
heroku ps:scale \
  aggregate=2:Standard-2X \
  aggregate_sweeper=1:Standard-1X \
  archive=1:Standard-1X
  drain=3:Standard-2X \
  logs=15:Standard-2X \
  purge=1:Standard-1X \
  web=2:Standard-1X \
  -a travis-logs-production`
```

- [ ] resume all ASG processes

``` bash
aws autoscaling resume-processes \
  --auto-scaling-group-name 'production-2-workers-org' \
  --scaling-processes 'Terminate'

aws autoscaling resume-processes \
  --auto-scaling-group-name 'precise-production-2-workers-org' \
  --scaling-processes 'Terminate'
```

## misc notes

Example sqitch deploy of migrations after `structure`, from a copy of the
production logs database:

```
$ time sqitch deploy db:pg://localhost/logs
Deploying changes to db:pg://localhost/logs
  + vacuum_settings ................ ok
  + log_parts_created_at_not_null .. ok
  + partman ........................ ok

real    0m1.203s
user    0m0.646s
sys     0m0.134s
```
