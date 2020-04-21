# frozen_string_literal: true

require 'uri'
require 'active_support/core_ext/hash/keys'
require 'sidekiq'
require 'travis/metrics/sidekiq'

module Travis
  module Logs
    module Sidekiq
      autoload :Aggregate, 'travis/logs/sidekiq/aggregate'
      autoload :Archive, 'travis/logs/sidekiq/archive'
      autoload :ErrorMiddleware, 'travis/logs/sidekiq/error_middleware'
      autoload :Honeycomb, 'travis/logs/sidekiq/honeycomb'
      autoload :LogParts, 'travis/logs/sidekiq/log_parts'
      autoload :PartmanMaintenance, 'travis/logs/sidekiq/partman_maintenance'
      autoload :Purge, 'travis/logs/sidekiq/purge'
      autoload :PusherForwarding, 'travis/logs/sidekiq/pusher_forwarding'
      autoload :TimingInfo, 'travis/logs/sidekiq/timing_info'

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
            size: Travis.config.sidekiq.pool_size,
            id: nil
          )
          ::Sidekiq.logger = sidekiq_logger
          ::Sidekiq.configure_server do |config|
            config.server_middleware do |chain|
              chain.add Travis::Logs::Sidekiq::ErrorMiddleware,
                        pause_time: Travis.config.logs.sidekiq_error_retry_pause

              chain.add Metrics::Sidekiq
              chain.add Travis::Honeycomb::Sidekiq
            end
          end
        end

        private def sidekiq_logger
          return ::Logger.new($stdout) if Travis.config.log_level.to_s == 'debug'

          nil
        end
      end
    end
  end
end
