# Travis Logs

[![Build Status](https://travis-ci.org/travis-ci/travis-logs.svg?branch=master)](https://travis-ci.org/travis-ci/travis-logs)

Travis Logs processes log updates which are streamed from [Travis
Worker](https://github.com/travis-ci/worker) instances via
[RabbitMQ](http://www.rabbitmq.com/). The log parts are streamed via
[Pusher](http://pusher.com/) to the web client ([Travis
Web](http://github.com/travis-ci/travis-web)) and added to the database.

Once all log parts have been received, and a timeout has passed (10 seconds
default), the log parts are aggregated into one final log.

Travis Logs archives logs to S3 and the database records are purged once it is
verified that the logs are archived correctly.

## Local Development

When developing locally, one may want to set certain config params via env vars,
such as a `DATABASE_URL` that points to a valid PostgreSQL server.  See the
`.example.env` file for examples.

## Process types

Some of the process types listed in [`./Procfile`](./Procfile) depend on other
process types, while others are independent:

### `drain` and `drain_sharded` process

The `drain` process is responsible for consuming log parts messages via AMQP and
batching them together as enqueued jobs in the `log_parts` sidekiq queue.
`drain_sharded` is the same, yet connects differently to AMQP.

### `web` process

The `web` process runs a Sinatra web app that exposes APIs to handle
interactions with other Travis applications and the external Pusher service.

### `worker_critical` process

The `worker_critical` process is responsible for handling jobs from the
following sidekiq queues:

#### `logs.pusher_forwarding` sidekiq queue

The jobs in the `logs.pusher_forwarding` queue forward each log part
individually to Pusher.

### `worker_high` process

The `worker_high` process is responsible for handling jobs from the following
sidekiq queues:

#### `log_parts` sidekiq queue

The jobs in the `log_parts` sidekiq queue write batches of log parts records to
the `log_parts` table.

#### `aggregate` sidekiq queue

The jobs in the `aggregate` sidekiq queue combine all `log_parts` records for a
given log id into a single content blob that is set on the corresponding `logs`
record and then deletes the `log_parts` records.

### `worker_low` process

The `worker_low` process is responsible for handling jobs from the following
sidekiq queues:

#### `archive` sidekiq queue

Jobs in the `archive` sidekiq queue move the content of each fully aggregated
log record from the database to S3.  Once archiving is complete, a job is sent
for consumption in the `purge` sidekiq queue.

#### `purge` sidekiq queue

Jobs in the `purge` sidekiq queue set the log record content to NULL after
verifying that the archived (S3) content fully matches the log record content.
If there is a mismatch, the log id is sent to the `archive` sidekiq queue for
re-archiving.

### `aggregate_sweeper` process

The `aggregate_sweeper` process is an optional process that periodically queries
the `log_parts` table for records that may have been missed by the event-based
aggregation process that flows through the `aggregate` sidekiq queue.

## Database specifics

### Schema management

The schema and migrations for travis-logs are managed with
[sqitch](http://sqitch.org/).  All of the deploy, verify, and revert scripts may
be found in the `./db/` directory.

To install sqitch locally, you can run:

```
$ script/install-sqitch
```

To run sqitch, you can run:

```
$ script/sqitch-heroku DATABASE_URL travis-logs-staging status
```

For more information on how to use sqitch and how to add migrations, you can
take a look at the [sqitch tutorial](https://metacpan.org/pod/sqitchtutorial).

### Data lifecycle

The process types above use PostgreSQL for various operations, with a structure
of two tables: `logs` and `log_parts`.  Normal operations may be generalized as
a progression from writing to `log_parts`, to combining those records into
`logs`, and then moving the content to S3.

For this reason, the `log_parts` table at any one time is mostly empty space,
with the size reported by PostgreSQL being significantly larger than what is
really there.  To a lesser degree, the `logs` table is also mostly empty,
although the live record count will continue to grow over the lifetime of a
deployment as metadata is retained after the content has been moved to S3.

### Partitioned `log_parts`

In order to address the empty space growth caused by the high record churn of
`log_parts`, the deployments of travis-logs used for hosted Travis CI use the
[pg_partman](https://github.com/keithf4/pg_partman) extension to drop daily
partitions that are 2 days old.

The partitions are maintained by running the `partman.run_maintenance` query,
triggered via a daily Heroku scheduled job.  Because the `log_parts` table is
being accessed constantly in production, and various operations within
`partman.run_maintenance` require a PostgreSQL lock type of
`AccessExclusiveLock` of the `log_parts` table, the implementation of the
maintenance operation includes a redis-based switch that prevents access to the
`log_parts` table via other processes.

During the maintenance operation, sidekiq workers will sleep and retry, then
resume upon maintenance completion.  Any requests to `web` dynos during
maintenance that require access to the `log_parts` table will return `503`.
This is certainly not ideal, and more changes may be considered to further
reduce production impact in the future.  In practice, the complete maintenance
operation lasts about 1 minute.

## License & copyright information

See LICENSE file.

Copyright (c) 2018 Travis CI GmbH

