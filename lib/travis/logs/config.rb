# frozen_string_literal: true
require 'travis/config'
require 'travis/support'

module Travis
  module Logs
    class Config < Travis::Config
      class << self
        def ssl?
          (env == 'production') && !disable_ssl?
        end

        def api_logging?
          %w(1 yes on true).include?(
            (
              ENV['TRAVIS_LOGS_API_LOGGING'] ||
              ENV['API_LOGGING']
            ).to_s.downcase
          )
        end

        def disable_ssl?
          %w(1 yes on true).include?(ENV['PG_DISABLE_SSL'].to_s.downcase)
        end

        def sql_logging?
          %w(1 yes on true).include?(
            ENV['TRAVIS_LOGS_SQL_LOGGING'] ||
            ENV['SQL_LOGGING'] || 'off'
          )
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
            ENV['INTERVALS_VACUUM'] || 60
          )
        end

        def per_aggregate_limit
          Integer(
            ENV['TRAVIS_LOGS_PER_AGGREGATE_LIMIT'] ||
            ENV['PER_AGGREGATE_LIMIT'] || 500
          )
        end

        def vacuum_skip_empty?
          %w(1 yes on true).include?(
            ENV['TRAVIS_LOGS_VACUUM_SKIP_EMPTY'] ||
            ENV['VACUUM_SKIP_EMPTY'] || 'on'
          )
        end

        def aggregatable_order
          ENV['TRAVIS_LOGS_AGGREGATABLE_ORDER'] ||
            ENV['AGGREGATABLE_ORDER'] || nil
        end
      end

      def env
        Travis.env
      end

      define(
        logs: {
          aggregatable_order: aggregatable_order,
          api_logging: api_logging?,
          archive: true,
          purge: false,
          threads: 10,
          per_aggregate_limit: per_aggregate_limit,
          aggregate_pool: {
            min_threads: aggregate_pool_min_threads,
            max_threads: aggregate_pool_max_threads,
            max_queue: 0
          },
          intervals: {
            vacuum: intervals_vacuum,
            sweeper: 10 * 60,
            regular: 3 * 60,
            force: 3 * 60 * 60,
            purge: 6
          },
          vacuum_skip_empty: vacuum_skip_empty?
        },
        log_level: :info,
        logger: { format_type: 'l2met', thread_id: true },
        amqp: {
          username: 'guest', password: 'guest', host: 'localhost', prefetch: 1
        },
        logs_database: {
          adapter: 'postgresql',
          database: "travis_logs_#{Travis.env}",
          ssl: ssl?,
          encoding: 'unicode',
          min_messages: 'warning',
          sql_logging: sql_logging?
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
        lock: { strategy: :redis, ttl: 150 },
        metrics: { reporter: 'librato' },
        ssl: {},
        sentry: {},
        investigation: { enabled: false, investigators: {} }
      )

      default(_access: [:key])
    end
  end
end
