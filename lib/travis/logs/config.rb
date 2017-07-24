# frozen_string_literal: true

require 'active_support/core_ext/integer'
require 'active_support/core_ext/numeric'
require 'active_support/core_ext/time'

require 'travis/config'

module Travis
  module Logs
    class Config < Travis::Config
      define(
        amqp: {
          automatic_recovery: true,
          recover_from_connection_close: true
        },
        channels_existence_check: true,
        lock: { strategy: :redis, ttl: 150 },
        log_level: :info,
        logger: { format_type: 'l2met', thread_id: true },
        logs: {
          aggregatable_order: nil,
          aggregate_clean_skip_empty: true,
          aggregate_pool: {
            max_queue: 0,
            max_threads: 20,
            min_threads: 20
          },
          api_logging: false,
          archive: true,
          archive_spoofing: {
            min_accepted_id: 0,
            min_accepted_job_id: 0
          },
          cache_size_bytes: 10.megabytes,
          drain_threads: 4,
          drain_batch_size: 100,
          drain_consumer_count: 10,
          drain_execution_interval: 3,
          drain_loop_sleep_interval: 10,
          drain_timeout_interval: 3,
          intervals: {
            aggregate: 1.minute,
            force: 3.hours,
            purge: 6.seconds,
            regular: 3.minutes,
            sweeper: 10.minutes
          },
          maintenance_expiry: 5.minutes,
          maintenance_initial_sleep: 30.seconds,
          per_aggregate_limit: 500,
          purge: false,
          sidekiq_error_retry_pause: 3.seconds
        },
        logs_database: {
          min_readable_cutoff_age: 6.months,
          sql_logging: false,
          url: ENV.fetch(
            'LOGS_DATABASE_URL',
            "postgres://localhost/travis_logs_#{env}"
          )
        },
        logs_readonly_database: {
          min_readable_cutoff_age: 6.months,
          sql_logging: false,
          url: ENV.fetch(
            'LOGS_READONLY_DATABASE_URL',
            "postgres://localhost/travis_logs_#{env}"
          )
        },
        memcached: {
          servers: ENV.fetch('MEMCACHIER_SERVERS', ''),
          username: ENV.fetch('MEMCACHIER_USERNAME', ''),
          password: ENV.fetch('MEMCACHIER_PASSWORD', '')
        },
        metrics: { reporter: 'librato' },
        pusher: {
          app_id: '',
          key: '',
          secret: '',
          secure: false
        },
        redis: { url: '' },
        s3: {
          access_key_id: '',
          acl: '',
          hostname: '',
          secret_access_key: ''
        },
        sentry: {
          dsn: ENV['SENTRY_DSN']
        },
        sidekiq: { namespace: 'sidekiq', pool_size: 7 }
      )

      def amqp
        super.to_h.merge(
          properties: {
            process: process_name
          }
        )
      end

      def metrics
        super.to_h.merge(librato: librato.to_h.merge(source: librato_source))
      end

      def librato_source
        ENV['LIBRATO_SOURCE'] || super
      end

      def memcached
        super.to_h
      end

      def process_name
        ['logs', env, ENV['DYNO'] || 'anon'].compact.join('.')
      end
    end
  end
end
