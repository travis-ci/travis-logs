# frozen_string_literal: true

require 'travis/config'

module Travis
  module Logs
    class Config < Travis::Config
      define(
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
          cache_size_bytes: 10_000_000,
          drain_threads: 4,
          drain_batch_size: 100,
          drain_execution_interval: 3,
          drain_timeout_interval: 3,
          intervals: {
            aggregate: 60,
            force: 3 * 60 * 60,
            purge: 6,
            regular: 3 * 60,
            sweeper: 10 * 60
          },
          per_aggregate_limit: 500,
          purge: false
        },
        logs_database: {
          sql_logging: false,
          url: ENV.fetch(
            'LOGS_DATABASE_URL',
            "postgres://localhost/travis_logs_#{env}"
          )
        },
        logs_readonly_database: {
          sql_logging: false,
          url: ENV.fetch(
            'LOGS_READONLY_DATABASE_URL',
            "postgres://localhost/travis_logs_#{env}"
          )
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

      def metrics
        super.to_h.merge(librato: librato.to_h.merge(source: librato_source))
      end

      def librato_source
        ENV['LIBRATO_SOURCE'] || super
      end
    end
  end
end
