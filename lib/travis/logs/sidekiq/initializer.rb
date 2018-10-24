# frozen_string_literal: true

if defined?(Sidekiq)
  libdir = File.expand_path('../../..', __dir__)
  $LOAD_PATH.unshift(libdir) unless $LOAD_PATH.include?(libdir)

  require 'travis/logs'

  $stdout.sync = true
  $stderr.sync = true

  Travis::Logs::Sidekiq.setup
end
