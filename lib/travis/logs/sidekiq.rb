# frozen_string_literal: true

require 'uri'
require 'sidekiq'

module Travis
  module Logs
    module Sidekiq
      autoload :Aggregate, 'travis/logs/sidekiq/aggregate'
      autoload :Archive, 'travis/logs/sidekiq/archive'
      autoload :LogParts, 'travis/logs/sidekiq/log_parts'
      autoload :Purge, 'travis/logs/sidekiq/purge'

      class << self
        def setup
          Travis.logger.info(
            'Setting up Sidekiq and Redis',
            pool_size: Travis.config.sidekiq.pool_size,
            host: URI(Travis.config.redis.url).host
          )
          ::Sidekiq.redis = Travis::Logs.redis_pool
          ::Sidekiq.logger = (
            Travis.logger if Travis.config.log_level == :debug
          )
        end

        def load_workers
          %i[Aggregate Archive LogParts Purge].each do |worker|
            const_get(worker)
          end
        end
      end
    end
  end
end
