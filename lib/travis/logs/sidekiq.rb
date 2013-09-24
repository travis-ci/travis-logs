require 'sidekiq'
require 'sidekiq/redis_connection'

module Travis
  module Logs
    module Sidekiq
      class << self
        def setup
          Travis.logger.info('Setting up Sidekiq and the Redis connection')
          Travis.logger.info("using redis:#{Logs.config.redis.inspect}")
          Travis.logger.info("using sidekiq:#{Logs.config.sidekiq.inspect}")
          url = Logs.config.redis.url
          namespace = Logs.config.sidekiq.namespace
          pool_size = Logs.config.sidekiq.pool_size
          ::Sidekiq.redis = ::Sidekiq::RedisConnection.create({ :url => url, :namespace => namespace, :size => pool_size })
          if Travis.config.log_level == :debug
            ::Sidekiq.logger = Travis.logger
          else
            ::Sidekiq.logger = nil
          end
        end
      end
    end
  end
end
