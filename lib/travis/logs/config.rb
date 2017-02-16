require 'travis/config'
require 'travis/support'

module Travis
  module Logs
    class Config < Travis::Config
      class << self
        def ssl?
          (env == 'production') && !disable_ssl?
        end

        def disable_ssl?
          %w(1 yes on).include?(ENV['PG_DISABLE_SSL'].to_s.downcase)
        end

        def aggregate_async?
          ENV.key?('TRAVIS_LOGS_AGGREGATE_ASYNC') ||
            ENV.key?('AGGREGATE_ASYNC')
        end

        def aggregate_pool_min_threads
          Integer(
            ENV['TRAVIS_LOGS_AGGREGATE_POOL_MIN_THREADS'] ||
            ENV['AGGREGATE_POOL_MIN_THREADS'] || 20
          )
        end

        def aggregate_pool_max_threads
          Integer(
            ENV['TRAVIS_LOGS_AGGREGATE_POOL_MAX_THREADS'] ||
            ENV['AGGREGATE_POOL_MAX_THREADS'] || 20
          )
        end

        def intervals_vacuum
          Integer(
            ENV['TRAVIS_LOGS_INTERVALS_VACUUM'] ||
            ENV['INTERVALS_VACUUM'] || 5
          )
        end
      end

      def env
        Travis.env
      end

      define(
        logs: {
          aggregate_async: aggregate_async?,
          archive: true,
          purge: false,
          threads: 10,
          per_aggregate_limit: 500,
          aggregate_pool: {
            min_threads: aggregate_pool_min_threads,
            max_threads: aggregate_pool_max_threads,
            max_queue: 0
          },
          intervals: {
            vacuum: intervals_vacuum,
            regular: 180,
            force: 3 * 60 * 60,
            purge: 6
          }
        },
        log_level: :info,
        logger: { format_type: 'l2met', thread_id: true },
        amqp: {
          username: 'guest', password: 'guest', host: 'localhost', prefetch: 1
        },
        logs_database: {
          adapter: 'postgresql', database: "travis_logs_#{Travis.env}",
          ssl: ssl?, encoding: 'unicode', min_messages: 'warning'
        },
        s3: {
          hostname: 'archive.travis-ci.org', access_key_id: '',
          secret_access_key: '', acl: :public_read
        },
        pusher: {
          app_id: 'app-id', key: 'key', secret: 'secret', secure: false
        },
        sidekiq: { namespace: 'sidekiq', pool_size: 22 },
        redis: { url: 'redis://localhost:6379' },
        metrics: { reporter: 'librato' },
        ssl: {},
        sentry: {},
        investigation: { enabled: false, investigators: {} }
      )

      default(_access: [:key])
    end
  end
end
