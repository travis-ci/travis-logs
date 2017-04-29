# frozen_string_literal: true

require 'forwardable'

require 'active_support'
require 'raven'
require 'raven/processor/removestacktrace'
require 'sidekiq/redis_connection'

require 'travis/exceptions'
require 'travis/logger'
require 'travis/metrics'

module Travis
  extend Forwardable
  def_delegators :'Travis::Logs', :config, :logger
  module_function :config, :logger

  module Logs
    autoload :Aggregate, 'travis/logs/aggregate'
    autoload :App, 'travis/logs/app'
    autoload :Config, 'travis/logs/config'
    autoload :Database, 'travis/logs/database'
    autoload :Drain, 'travis/logs/drain'
    autoload :DrainQueue, 'travis/logs/drain_queue'
    autoload :Existence, 'travis/logs/existence'
    autoload :Lock, 'travis/logs/lock'
    autoload :Maintenance, 'travis/logs/maintenance'
    autoload :MetricsMethods, 'travis/logs/metrics_methods'
    autoload :MetricsMiddleware, 'travis/logs/metrics_middleware'
    autoload :Pusher, 'travis/logs/pusher'
    autoload :RedisPool, 'travis/logs/redis_pool'
    autoload :S3, 'travis/logs/s3'
    autoload :SentryMiddleware, 'travis/logs/sentry_middleware'
    autoload :Services, 'travis/logs/services'
    autoload :Sidekiq, 'travis/logs/sidekiq'
    autoload :UnderMaintenanceError, 'travis/logs/under_maintenance_error'

    class << self
      attr_writer :config, :database_connection

      def config
        @config ||= Travis::Logs::Config.load
      end

      def logger
        @logger ||= Travis::Logger.configure(
          Travis::Logger.new($stdout),
          config
        )
      end

      def database_connection
        @database_connection ||= Travis::Logs::Database.connect
      end

      def readonly_database_connection
        @readonly_database_connection ||= Travis::Logs::Database.connect(
          config: config.logs_readonly_database.to_h
        )
      end

      def redis
        @redis ||= Travis::Logs::RedisPool.new(redis_config)
      end

      def redis_config
        (config.logs_redis || config.redis || {}).to_h
      end

      def version
        @version ||= ENV.fetch(
          'HEROKU_SLUG_COMMIT',
          `git rev-parse HEAD 2>/dev/null`
        ).strip
      end

      def cache
        @cache ||= build_cache
      end

      private def build_cache
        if config.memcached[:servers].to_s.empty?
          return ActiveSupport::Cache::MemoryStore.new(
            size: config.logs.cache_size_bytes
          )
        end

        require 'connection_pool'
        require 'active_support/cache/dalli_store'

        ActiveSupport::Cache::DalliStore.new(
          config.memcached[:servers].to_s.split(','),
          username: config.memcached[:username],
          password: config.memcached[:password],
          namespace: 'logs'
        )
      end

      def setup
        setup_exceptions
        setup_metrics
        setup_s3
      end

      private def setup_exceptions
        Travis::Exceptions.setup(config, config.env, logger)

        Raven.configure do |c|
          c.release = version
          c.excluded_exceptions = %w[Travis::Logs::UnderMaintenanceError]
          c.processors << Raven::Processor::RemoveStacktrace
        end
      end

      private def setup_metrics
        Travis::Metrics.setup(config.metrics, logger)
      end

      private def setup_s3
        Travis::Logs::S3.setup
      end
    end

    setup
  end
end
