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
            "Setting up Sidekiq (pool size: #{pool_size}) and Redis " <<
            "(connecting to host #{URI.parse(url).host})"
          )

          ::Sidekiq.redis = ::Sidekiq::RedisConnection.create(
            url: url,
            namespace: Logs.config.sidekiq.namespace,
            size: pool_size
          )

          if Travis.config.log_level == :debug
            ::Sidekiq.logger = Travis.logger
          else
            ::Sidekiq.logger = nil
          end

          :alldone
        end
      end
    end
  end
end
