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
          ::Sidekiq.configure_client do |c|
            c.logger = Travis.logger
            c.redis = ::Sidekiq::RedisConnection.create({ :url => url, :namespace => namespace, :size => pool_size })
          end
        end
      end
    end
  end
end
