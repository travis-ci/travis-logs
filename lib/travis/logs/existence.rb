require 'redis'

module Travis
  module Logs
    class Existence
      attr_reader :redis

      def initialize
        @redis  = Redis.new(url: Logs.config.redis.url)
      end

      def occupied!(channel_name)
        redis.set(key(channel_name), true)
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

