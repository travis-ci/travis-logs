# Travis Logs
**************************

[![Build Status](https://travis-ci.org/travis-ci/travis-logs.png?branch=master)](https://travis-ci.org/travis-ci/travis-logs)

Travis Logs processes log updates which are streamed from [Travis Worker](https://github.com/travis-ci/travis-worker) instances via [RabbitMQ](http://www.rabbitmq.com/). The log parts are streamed via [Pusher](http://pusher.com/) to the web client ([Travis Web](http://github.com/travis-ci/travis-web)) and added to the database.

Once all log parts have been received, and a timeout has passed (10 seconds default), the log parts are aggregated into one final log.

Although Travis Logs is built to archive logs to S3, and vacuum from the database once it is verified that the logs are archived correctly. This has been run for all previous logs prior to January but it not active at the moment.

![Travis Logs Diagram](/img/diagram.jpg)

## License & copyright information ##

See LICENSE file.

Copyright (c) 2011 [Travis CI development team](https://github.com/travis-ci).

