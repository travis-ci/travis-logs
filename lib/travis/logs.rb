# frozen_string_literal: true

require 'forwardable'

require 'sidekiq/redis_connection'

require 'travis/logger'

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
    autoload :Metrics, 'travis/logs/metrics'
    autoload :MetricsMiddleware, 'travis/logs/metrics_middleware'
    autoload :Pusher, 'travis/logs/pusher'
    autoload :RedisPool, 'travis/logs/redis_pool'
    autoload :S3, 'travis/logs/s3'
    autoload :Services, 'travis/logs/services'
    autoload :Sidekiq, 'travis/logs/sidekiq'

    class << self
      attr_writer :config, :database_connection, :redis_pool

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

      def redis_pool
        @redis_pool ||= ::Sidekiq::RedisConnection.create(
          url: config.redis.url,
          namespace: config.sidekiq.namespace,
          size: config.sidekiq.pool_size
        )
      end

      def version
        @version ||= ENV.fetch(
          'HEROKU_SLUG_COMMIT',
          `git rev-parse HEAD 2>/dev/null`
        ).strip
      end
    end
  end
end
