require 'uri'
require 'sidekiq'
require 'sidekiq/redis_connection'

module Travis
  module Logs
    module Sidekiq
      class << self
        def setup
          url = Logs.config.redis.url
          pool_size = Logs.config.sidekiq.pool_size

          Travis.logger.info(
            'Setting up Sidekiq and Redis',
            pool_size: pool_size,
            host: URI(url).host
          )
          ::Sidekiq.redis = ::Sidekiq::RedisConnection.create(
            url: url,
            namespace: Logs.config.sidekiq.namespace,
            size: pool_size
          )
          ::Sidekiq.logger = (
            Travis.logger if Travis.config.log_level == :debug
          )
        end
      end
    end
  end
end
