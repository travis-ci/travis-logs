require 'travis/config'
require 'travis/support'

module Travis
  module Logs
    class Config < Travis::Config
      class << self
        def default_amqp_url
          ENV[ENV['AMQP_PROVIDER'] || ''] ||
            ENV['CLOUDAMQP_URL'] ||
            ENV['RABBITMQ_BIGWIG_URL'] ||
            'amqp://guest:guest@localhost:5672'
        end

        def default_logs_database_url
          ENV[ENV['DATABASE_PROVIDER'] || ''] ||
            ENV['LOGS_DATABASE_URL'] ||
            ENV['DATABASE_URL'] ||
            "postgres://localhost:5432/travis_logs_#{Travis.env}"
        end

        def default_redis_url
          ENV[ENV['REDIS_PROVIDER'] || ''] ||
            ENV['REDIS_URL'] ||
            ENV['REDISGREEN_URL'] ||
            ENV['OPENREDIS_URL'] ||
            'redis://localhost:6379'
        end
      end

      define(
        amqp: {
          url: default_amqp_url,
          prefetch: 1
        },
        logs_database: {
          url: default_logs_database_url,
          adapter: 'postgresql',
          encoding: 'unicode',
          min_messages: 'warning'
        },
        s3: {
          hostname: 'archive.travis-ci.org',
          access_key_id: '',
          secret_access_key: '',
          acl: :public_read
        },
        pusher: {
          app_id: 'app-id',
          key: 'key',
          secret: 'secret',
          secure: false
        },
        sidekiq: {
          namespace: 'sidekiq',
          pool_size: 3
        },
        logs: {
          archive: true,
          purge: false,
          threads: 10,
          intervals: {
            vacuum: 10,
            regular: 180,
            force: 3 * 60 * 60,
            purge: 6
          }
        },
        redis: {
          url: default_redis_url
        },
        metrics: {
          reporter: 'librato'
        },
        ssl: {},
        sentry: {}
      )

      default _access: [:key]

      def env
        Travis.env
      end
    end
  end
end
