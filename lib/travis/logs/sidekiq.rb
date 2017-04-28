# frozen_string_literal: true

require 'uri'
require 'sidekiq'

module Travis
  module Logs
    module Sidekiq
      autoload :Aggregate, 'travis/logs/sidekiq/aggregate'
      autoload :Archive, 'travis/logs/sidekiq/archive'
      autoload :ErrorMiddleware, 'travis/logs/sidekiq/error_middleware'
      autoload :LogParts, 'travis/logs/sidekiq/log_parts'
      autoload :PartmanMaintenance, 'travis/logs/sidekiq/partman_maintenance'
      autoload :Purge, 'travis/logs/sidekiq/purge'

      class << self
        def setup
          Travis.logger.info(
            'setting up sidekiq and redis',
            pool_size: Travis.config.sidekiq.pool_size,
            host: URI(Travis.config.redis.url).host
          )
          ::Sidekiq.redis = ::Sidekiq::RedisConnection.create(
            url: Travis.config.redis.url,
            namespace: Travis.config.sidekiq.namespace,
            size: Travis.config.sidekiq.pool_size
          )
          ::Sidekiq.logger = ::Logger.new($stdout) if debug?
          ::Sidekiq.configure_server do |config|
            config.server_middleware do |chain|
              chain.add Travis::Logs::Sidekiq::ErrorMiddleware
            end
          end
        end

        def debug?
          Travis.config.log_level.to_s == 'debug'
        end
      end
    end
  end
end
