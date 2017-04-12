# frozen_string_literal: true

require 'travis/config'

module Travis
  module Logs
    class Config < Travis::Config
      extend Hashr::Env

      self.env_namespace = 'TRAVIS'

      define(
        logs: {
          aggregatable_order: nil,
          api_logging: false,
          archive: true,
          aggregate_clean_skip_empty: true,
          purge: false,
          threads: 10,
          per_aggregate_limit: 500,
          aggregate_pool: {
            min_threads: 20,
            max_threads: 20,
            max_queue: 0
          },
          archive_spoofing: {
            min_accepted_job_id: 0,
            min_accepted_id: 0
          },
          intervals: {
            aggregate: 60,
            sweeper: 10 * 60,
            regular: 3 * 60,
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
          url: ENV.fetch(
            'LOGS_DATABASE_URL',
            "postgres://localhost/travis_logs_#{env}"
          ),
          adapter: 'postgresql',
          database: "travis_logs_#{env}",
          encoding: 'unicode',
          min_messages: 'warning',
          sql_logging: false,
          log_parts_autovacuum_vacuum_threshold: 0,
          log_parts_autovacuum_vacuum_scale_factor: 0.001,
          vacuum_cost_limit: 10_000,
          vacuum_cost_delay: 20
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
        sentry: {},
        investigation: { enabled: false, investigators: {} }
      )

      default(_access: [:key])

      def metrics
        super.to_h.merge(librato: librato.to_h.merge(source: librato_source))
      end

      def librato_source
        ENV['LIBRATO_SOURCE'] || super
      end
    end
  end
end
