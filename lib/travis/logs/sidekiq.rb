require 'sidekiq'
require 'securerandom'
require 'core_ext/securerandom'

module Travis
  module Logs
    module Sidekiq
      class << self
        def setup
          url = Logs.config.redis.url
          namespace = Logs.config.sidekiq.namespace
          pool_size = Logs.config.sidekiq.pool_size
          ::Sidekiq.configure_client do |c|
            c.redis = { :url => url, :namespace => namespace, :size => pool_size }
          end
        end

        def queue_archive_job(payload)
          args = [SecureRandom.uuid, 'Travis::Addons::Archive::Task', 'perform', payload]
          ::Sidekiq::Client.push('queue' => 'archive', 'retry' => 8, 'class' => 'Travis::Async::Sidekiq::Worker', 'args' => args)
        end
      end
    end
  end
end
