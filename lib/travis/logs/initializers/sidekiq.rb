require 'bundler/setup'

require 'travis/logs'
require 'travis/support'
require 'travis/support/exceptions/reporter'
require 'travis/logs/services/archive_logs'
require 'travis/logs/helpers/database'
require 'travis/logs/helpers/reporting'
require 'active_support/core_ext/logger'
require 'sidekiq'
require 'core_ext/hash/deep_symbolize_keys'

$stdout.sync = true
Travis.logger.info('** Setting up Sidekiq **')

Travis::Database.connect
Travis::Logs::Helpers::Reporting.setup
Travis::Exceptions::Reporter.start

Travis::Logs.database_connection = Travis::Logs::Helpers::Database.connect

Sidekiq.configure_server do |config|
  config.redis = {
    :url       => Travis::Logs.config.redis.url,
    :namespace => Travis::Logs.config.sidekiq.namespace
  }
  config.logger = nil unless Travis::Logs.config.log_level == :debug
end

module Travis
  module Logs
    module Sidekiq
      class Archiver
        include Sidekiq::Worker

        sidekiq_options queue: 'archive'

        def perform(params)
          puts params.inspect
        end
      end
    end
  end
end