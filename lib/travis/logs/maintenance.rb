# frozen_string_literal: true

require 'travis/logs'

module Travis
  module Logs
    class Maintenance
      MAINTENANCE_KEY = 'travis-logs:maintenance'

      def initialize(redis: Travis::Logs.redis,
                     expiry: Travis.config.logs.maintenance_expiry)
        @redis = redis
        @expiry = expiry
      end

      attr_reader :redis, :expiry
      private :redis

      def with_maintenance_on
        redis.setex(MAINTENANCE_KEY, expiry, 'on')
        yield
      ensure
        redis.del(MAINTENANCE_KEY)
      end

      def enabled?
        redis.get(MAINTENANCE_KEY) == 'on'
      end

      def restrict!
        return unless enabled?

        raise Travis::Logs::UnderMaintenanceError, redis.ttl(MAINTENANCE_KEY)
      end
    end
  end
end
