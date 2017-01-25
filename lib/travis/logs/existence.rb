require 'redis'
require 'travis/redis_pool'

module Travis
  module Logs
    class Existence
      attr_reader :redis

      class << self
        def redis
          @redis ||= RedisPool.new(redis_config)
        end

        def redis_config
          (Logs.config.logs_redis || Logs.config.redis || {}).to_h
        end
      end

      def initialize
        @redis = self.class.redis
      end

      def occupied!(channel_name)
        key = self.key(channel_name)
        redis.set(key, true)
        redis.expire(key, 6 * 3600)
      end

      def occupied?(channel_name)
        redis.get(key(channel_name))
      end

      def vacant?(channel_name)
        !occupied?(channel_name)
      end

      def vacant!(channel_name)
        redis.del(key(channel_name))
      end

      def key(channel_name)
        "logs:channel-occupied:#{channel_name}"
      end
    end
  end
end
