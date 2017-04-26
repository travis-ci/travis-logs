# frozen_string_literal: true

require 'simplecov'

ENV['ENV'] = ENV['RACK_ENV'] = 'test'
ENV['REDIS_URL'] = 'redis://localhost:6379/0'
ENV['TRAVIS_S3_HOSTNAME'] = 'archive-test.travis-ci.org'
ENV['TRAVIS_LOGS_DRAIN_BATCH_SIZE'] = '1'

require 'travis/logs'

Travis.logger.level = Logger::FATAL
