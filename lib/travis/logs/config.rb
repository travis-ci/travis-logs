require 'travis/config'
require 'travis/support'

module Travis
  module Logs
    class Config < Travis::Config
      def self.ssl?
        env == 'production' and not disable_ssl?
      end

      def self.disable_ssl?
        %w(1 yes on).include?(ENV['PG_DISABLE_SSL'].to_s.downcase)
      end

      def self.amqp_ssl?
        match = /^amqps:\/\//.match(ENV['RABBITMQ_URL'])
        match && match.size > 0
      end

      define  amqp:          { username: 'guest', password: 'guest', host: 'localhost', prefetch: 1, ssl: amqp_ssl? },
              logs_database: { adapter: 'postgresql', database: "travis_logs_#{env}", ssl: ssl?, encoding: 'unicode', min_messages: 'warning' },
              s3:            { hostname: "archive.travis-ci.org", access_key_id: '', secret_access_key: '', acl: :public_read },
              pusher:        { app_id: 'app-id', key: 'key', secret: 'secret', secure: false },
              sidekiq:       { namespace: 'sidekiq', pool_size: 3 },
              logs:          { archive: true, purge: false, threads: 10, intervals: { vacuum: 10, regular: 180, force: 3 * 60 * 60, purge: 6 } },
              redis:         { url: 'redis://localhost:6379' },
              lock:          { strategy: :redis, ttl: 150 },
              metrics:       { reporter: 'librato' },
              ssl:           { },
              sentry:        { },
              investigation: { enabled: false, investigators: {} }
    end
  end
end
