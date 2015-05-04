require 'travis/config'
require 'travis/support'

module Travis
  module Logs
    class Config < Travis::Config
      define  amqp:          { username: 'guest', password: 'guest', host: 'localhost', prefetch: 1 },
              logs_database: { adapter: 'postgresql', database: "travis_logs_#{Travis.env}", encoding: 'unicode', min_messages: 'warning' },
              log_storage_provider: 's3', #or 'file_storage'
              s3:            { hostname: "archive.travis-ci.org", access_key_id: '', secret_access_key: '', acl: :public_read },
              file_storage:  { root_path: '/var/tmp/travis-logs/' },
              pusher:        { app_id: 'app-id', key: 'key', secret: 'secret', secure: false },
              sidekiq:       { namespace: 'sidekiq', pool_size: 3 },
              logs:          { archive: true, purge: false, threads: 10, intervals: { vacuum: 10, regular: 180, force: 3 * 60 * 60, purge: 6 } },
              redis:         { url: 'redis://localhost:6379' },
              metrics:       { reporter: 'librato' },
              ssl:           { },
              sentry:        { }

      default _access: [:key]

      def env
        Travis.env
      end
    end
  end
end
