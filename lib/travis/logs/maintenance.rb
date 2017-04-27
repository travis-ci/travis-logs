# frozen_string_literal: true

require 'travis/logs'

module Travis
  module Logs
    class Maintenance
      class UnderMaintenanceError < StandardError
        def initialize(ttl)
          @ttl = ttl
        end

        attr_reader :ttl
        private :ttl

        def http_status
          503
        end

        def message
          "under maintenance for the next #{ttl}s"
        end
      end

      MAINTENANCE_KEY = 'travis-logs:maintenance'

      def initialize(redis: Travis::Logs.redis,
                     expiry: Travis.config.logs.maintenance_expiry_secs)
        @redis = redis
        @expiry = expiry
      end

      attr_reader :redis, :expiry
      private :redis
      private :expiry

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
        raise UnderMaintenanceError, redis.ttl(MAINTENANCE_KEY)
      end
    end
  end
end
