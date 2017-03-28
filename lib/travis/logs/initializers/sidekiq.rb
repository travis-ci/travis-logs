# frozen_string_literal: true
$LOAD_PATH << 'lib'

require 'travis/logs'
require 'travis/support'
require 'travis/support/exceptions/reporter'
require 'travis/logs/helpers/database'
require 'travis/logs/helpers/s3'
require 'active_support/core_ext/logger'
require 'travis/logs/sidekiq'
require 'core_ext/hash/deep_symbolize_keys'

$stdout.sync = true
Travis.logger.info('Setting up Sidekiq')

Travis::Logs::Helpers::S3.setup
Travis::Exceptions::Reporter.start
Travis::Metrics.setup
Travis::Logs::Sidekiq.setup

require 'travis/logs/sidekiq/aggregate'
require 'travis/logs/sidekiq/archive'
require 'travis/logs/sidekiq/purge'
