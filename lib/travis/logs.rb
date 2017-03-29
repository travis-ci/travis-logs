# frozen_string_literal: true
require 'sidekiq/redis_connection'
require 'travis/logs/config'
require 'travis/logs/helpers/database'

if RUBY_PLATFORM =~ /^java/
  require 'jrjackson'
else
  require 'oj'
end

module Travis
  def self.config
    Travis::Logs.config
  end

  module Logs
    class << self
      attr_writer :config, :database_connection, :redis_pool

      def config
        @config ||= Travis::Logs::Config.load
      end

      def database_connection
        @database_connection ||= Travis::Logs::Helpers::Database.connect
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
