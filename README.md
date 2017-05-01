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

### `drain` process

The `drain` process is responsible for consuming log parts messages via AMQP and
batching them together as enqueued jobs in the `log_parts` sidekiq queue.

### `web` process

The `web` process runs a Sinatra web app that exposes APIs to handle
interactions with other Travis applications and the external Pusher service.

### `worker_high` process

The `worker_high` process is responsible for handling jobs from the following
sidekiq queues:

#### `log_parts` sidekiq queue

The jobs in the `log_parts` sidekiq queue write batches of log parts records to
the `log_parts` table and forward each log part individually to Pusher.

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

## License & copyright information

See LICENSE file.

Copyright (c) 2011-2017 Travis CI GmbH
