require 'travis/config'
require 'travis/support'

module Travis
  module Logs
    class Config < Travis::Config
      def self.ssl?
        (env == 'production') && !disable_ssl?
      end

      def self.disable_ssl?
        %w(1 yes on).include?(ENV['PG_DISABLE_SSL'].to_s.downcase)
      end

      def self.aggregate_async?
        ENV.key?('AGGREGATE_ASYNC')
      end

      define(
        logs: {
          aggregate_async: aggregate_async?,
          archive: true,
          purge: false,
          threads: 10,
          per_aggregate_limit: 500,
          aggregate_pool: {
            min_threads: 20,
            max_threads: 20,
            max_queue: 0
          },
          intervals: {
            vacuum: 10,
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

      def env
        Travis.env
      end
    end
  end
end
