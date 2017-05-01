# frozen_string_literal: true

require 'active_support/core_ext/numeric/time'

require 'travis/logs'

module Travis
  module Logs
    class Existence
      attr_reader :redis, :expiry
      private :redis
      private :expiry

      def initialize(redis: Travis::Logs.redis, expiry: 6.hours)
        @redis = redis
        @expiry = expiry
      end

      def occupied!(channel_name)
        redis.setex(key(channel_name), expiry, 1)
      end

      def occupied?(channel_name)
        !redis.get(key(channel_name)).nil?
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
