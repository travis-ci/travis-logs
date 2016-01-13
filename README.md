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

## Process types

Some of the process types listed in [`./Procfile`](./Procfile) depend on other
process types, while others are independent:

### `logs`

The `logs` process is responsible for consuming log parts messages via AMQP, writing
each log part to the logs database, and sending the log part to Pusher.

### `web`

The `web` process runs a Sinatra web app that exposes APIs to handle Pusher
webhook events and to set log contents.

### `aggregate`

The `aggregate` process is responsible for finding all log parts that are
eligible for "aggregation" into single log records.  The aggregation itself may
either be done within the `aggregate` process or offloaded to the `aggregator`
process via Sidekiq.  Once aggregation is complete, a job is sent for
consumption by the `archive` process via Sidekiq.

### `aggregator`

The `aggregator` process is an optional complement to the `aggregate` process,
handling the heavy lifting via Sidekiq so that aggregation may be performed in
parallel.

### `archive`

The `archive` process is responsible for moving the content of each fully
aggregated log record from the database to S3.  Once archiving is complete, a
job is sent for consumption by the `purge` process via Sidekiq.

### `purge`

The `purge` process is responsible for setting log record content to NULL after
verifying that the archived (S3) content fully matches the log record content.
If there is a mismatch, the log id is sent to the `archive` process for
re-archiving via Sidekiq.

## License & copyright information

See LICENSE file.

Copyright (c) 2011-2016 Travis CI GmbH
