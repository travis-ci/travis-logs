# frozen_string_literal: true

if defined?(Sidekiq)
  libdir = File.expand_path('../../../../', __FILE__)
  $LOAD_PATH.unshift(libdir) unless $LOAD_PATH.include?(libdir)

  require 'active_support/core_ext/hash/keys'

  require 'travis/exceptions'
  require 'travis/logs'
  require 'travis/metrics'

  $stdout.sync = true
  $stderr.sync = true

  Travis::Logs::S3.setup
  Travis::Exceptions.setup(Travis.config, Travis.config.env, Travis.logger)
  Travis::Metrics.setup(Travis.config.metrics, Travis.logger)
  Travis::Logs::Sidekiq.setup
  Travis::Logs::Sidekiq.load_workers
end
