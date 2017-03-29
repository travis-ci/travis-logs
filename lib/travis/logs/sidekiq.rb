# frozen_string_literal: true
require 'uri'
require 'sidekiq'

module Travis
  module Logs
    module Sidekiq
      class << self
        def setup
          Travis.logger.info(
            'Setting up Sidekiq and Redis',
            pool_size: Travis::Logs.config.sidekiq.pool_size,
            host: URI(Travis::Logs.config.redis.url).host
          )
          ::Sidekiq.redis = Travis::Logs.redis_pool
          ::Sidekiq.logger = (
            Travis.logger if Travis.config.log_level == :debug
          )
        end
      end
    end
  end
end
