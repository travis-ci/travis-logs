# Planning `pg_partman` usage

Official docs available
[here](https://github.com/keithf4/pg_partman/tree/master/doc).

## Expected steps

The below steps specify travis-ci.org production applications. The same or
similar process _should_ work for travis-ci.com.

### preparation

- Get PostgreSQL 9.6 upgrade timing from a forked version
- Announce maintenance window at least 2d ahead of time

### create gap in `log_parts`

- `heroku ps:scale scheduler=0 -a travis-scheduler-production`
- Disable termination on all ASGs
- Wait up to 50m for current jobs to complete
- `heroku ps:scale logs=0 -a travis-logs-production`
- `heroku ps:scale scheduler=2 -a travis-scheduler-production`
- Wait for log parts aggregation to complete

### prepare for partitioning

- `heroku pg:upgrade LOGS_DATABASE -a travis-logs-production`
- Truncate the `log_parts` table, then run migration to alter the
  `created_at` column to be `NOT NULL` with `DEFAULT '2000-01-01'::timestamptz`.

### enable `pg_partman` and create partitions

- Run this:

``` sql
CREATE SCHEMA partman;

CREATE EXTENSION pg_partman SCHEMA partman;

SELECT partman.create_parent(
  'public.log_parts',
  'created_at',
  'time',
  'daily',
  p_constraint_cols := '{"log_id"}'::text[],
  p_premake := 2,
  p_upsert := 'ON CONFLICT(id) DO UPDATE SET val=EXCLUDED.val'
);
```

- `heroku addons:create scheduler:standard -a travis-logs-production`
- Configure the scheduler addon to run daily:

``` bash
psql -d "${LOGS_DATABASE_URL}" -c "SELECT partman.run_maintenance('public.log_parts');"
```

### resume writes to `log_parts`

- `heroku ps:scale logs=5:Performance-M -a travis-logs-production`
- (other?)
