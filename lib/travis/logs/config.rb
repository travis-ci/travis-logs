# frozen_string_literal: true

require 'travis/config'

module Travis
  module Logs
    class Config < Travis::Config
      extend Hashr::Env

      self.env_namespace = 'TRAVIS'

      define(
        amqp: {
          host: 'localhost',
          password: 'guest',
          prefetch: 1,
          username: 'guest'
        },
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
          drain_threads: 10,
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
          adapter: 'postgresql',
          database: "travis_logs_#{env}",
          encoding: 'unicode',
          log_parts_autovacuum_vacuum_scale_factor: 0.001,
          log_parts_autovacuum_vacuum_threshold: 0,
          min_messages: 'warning',
          sql_logging: false,
          url: ENV.fetch(
            'LOGS_DATABASE_URL',
            "postgres://localhost/travis_logs_#{env}"
          ),
          vacuum_cost_delay: 20,
          vacuum_cost_limit: 10_000
        },
        metrics: { reporter: 'librato' },
        pusher: {
          app_id: 'app-id',
          key: 'key',
          secret: 'secret',
          secure: false
        },
        redis: { url: 'redis://localhost:6379' },
        s3: {
          access_key_id: '',
          acl: :public_read,
          hostname: 'archive.travis-ci.org',
          secret_access_key: ''
        },
        sentry: {},
        sidekiq: { namespace: 'sidekiq', pool_size: 7 }
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
