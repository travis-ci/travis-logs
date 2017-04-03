# frozen_string_literal: true

require 'travis/config'

module Travis
  module Logs
    class Config < Travis::Config
      class << self
        def ssl?
          (env == 'production') && !disable_ssl?
        end

        def api_logging?
          %w(1 yes on true).include?(envvar('API_LOGGING').to_s.downcase)
        end

        def disable_ssl?
          %w(1 yes on true).include?(ENV['PG_DISABLE_SSL'].to_s.downcase)
        end

        def sql_logging?
          %w(1 yes on true).include?(envvar('SQL_LOGGING', 'off'))
        end

        def aggregate_pool_min_threads
          Integer(envvar('AGGREGATE_POOL_MIN_THREADS', 20))
        end

        def aggregate_pool_max_threads
          Integer(envvar('AGGREGATE_POOL_MAX_THREADS', 20))
        end

        def intervals_aggregate
          Integer(envvar('INTERVALS_AGGREGATE', 60))
        end

        def per_aggregate_limit
          Integer(envvar('PER_AGGREGATE_LIMIT', 500))
        end

        def aggregate_clean_skip_empty?
          %w(1 yes on true).include?(envvar('AGGREGATE_CLEAN_SKIP_EMPTY', 'on'))
        end

        def aggregatable_order
          envvar('AGGREGATABLE_ORDER', nil)
        end

        def archive_spoofing_min_accepted_job_id
          Integer(envvar('ARCHIVE_SPOOFING_MIN_ACCEPTED_JOB_ID', 0))
        end

        def archive_spoofing_min_accepted_id
          Integer(envvar('ARCHIVE_SPOOFING_MIN_ACCEPTED_ID', 0))
        end

        def log_parts_autovacuum_vacuum_threshold
          Integer(envvar('LOG_PARTS_AUTOVACUUM_VACUUM_THRESHOLD', 0))
        end

        def log_parts_autovacuum_vacuum_scale_factor
          Float(envvar('LOG_PARTS_AUTOVACUUM_VACUUM_SCALE_FACTOR', 0.001))
        end

        def vacuum_cost_limit
          Integer(envvar('VACUUM_COST_LIMIT', 10_000))
        end

        def vacuum_cost_delay
          Integer(envvar('VACUUM_COST_DELAY', 20))
        end

        private def envvar(suffix, default = nil)
          ENV["TRAVIS_LOGS_#{suffix}"] || ENV[suffix] || default
        end
      end

      define(
        logs: {
          aggregatable_order: aggregatable_order,
          api_logging: api_logging?,
          archive: true,
          aggregate_clean_skip_empty: aggregate_clean_skip_empty?,
          purge: false,
          threads: 10,
          per_aggregate_limit: per_aggregate_limit,
          aggregate_pool: {
            min_threads: aggregate_pool_min_threads,
            max_threads: aggregate_pool_max_threads,
            max_queue: 0
          },
          archive_spoofing: {
            min_accepted_job_id: archive_spoofing_min_accepted_job_id,
            min_accepted_id: archive_spoofing_min_accepted_id
          },
          intervals: {
            aggregate: intervals_aggregate,
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
          adapter: 'postgresql',
          database: "travis_logs_#{Travis::Config.env}",
          ssl: ssl?,
          encoding: 'unicode',
          min_messages: 'warning',
          sql_logging: sql_logging?,
          log_parts_autovacuum_vacuum_threshold:
            log_parts_autovacuum_vacuum_threshold,
          log_parts_autovacuum_vacuum_scale_factor:
            log_parts_autovacuum_vacuum_scale_factor,
          vacuum_cost_limit: vacuum_cost_limit,
          vacuum_cost_delay: vacuum_cost_delay
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
