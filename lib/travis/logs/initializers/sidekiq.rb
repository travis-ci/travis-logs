# frozen_string_literal: true

libdir = File.expand_path('../../../../', __FILE__)
$LOAD_PATH.unshift(libdir) unless $LOAD_PATH.include?(libdir)

require 'active_support/core_ext/logger'
require 'core_ext/hash/deep_symbolize_keys'

require 'travis/logs'
require 'travis/logs/helpers/database'
require 'travis/logs/helpers/s3'
require 'travis/logs/sidekiq'
require 'travis/support'
require 'travis/support/exceptions/reporter'

$stdout.sync = true
Travis.logger.info('Setting up Sidekiq')

Travis::Logs::Helpers::S3.setup
Travis::Exceptions::Reporter.start
Travis::Metrics.setup
Travis::Logs::Sidekiq.setup

require 'travis/logs/sidekiq/aggregate'
require 'travis/logs/sidekiq/archive'
require 'travis/logs/sidekiq/log_parts'
require 'travis/logs/sidekiq/purge'
