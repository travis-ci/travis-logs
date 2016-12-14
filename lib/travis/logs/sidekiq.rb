require 'sidekiq'
require 'sidekiq/redis_connection'

module Travis
  module Logs
    module Sidekiq
      class << self
        def setup
          url = Logs.config.redis.url
          redis_host = URI.parse(url).host
          pool_size = Logs.config.sidekiq.pool_size
          namespace = Logs.config.sidekiq.namespace

          Travis.logger.info("Setting up Sidekiq (pool size: #{pool_size}) and Redis (connecting to host #{redis_host})")
          ::Sidekiq.redis = ::Sidekiq::RedisConnection.create(url: url, namespace: namespace, size: pool_size)
          ::Sidekiq.logger = (Travis.logger if Travis.config.log_level == :debug)
        end
      end
    end
  end
end
