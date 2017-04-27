# frozen_string_literal: true

require 'uri'
require 'sidekiq'

module Travis
  module Logs
    module Sidekiq
      autoload :Aggregate, 'travis/logs/sidekiq/aggregate'
      autoload :Archive, 'travis/logs/sidekiq/archive'
      autoload :LogParts, 'travis/logs/sidekiq/log_parts'
      autoload :PartmanMaintenance, 'travis/logs/sidekiq/partman_maintenance'
      autoload :Purge, 'travis/logs/sidekiq/purge'

      class << self
        def setup
          Travis.logger.info(
            'setting up sidekiq and redis',
            pool_size: Travis.config.sidekiq.pool_size,
            host: URI(Travis.config.redis.url).host
          )
          ::Sidekiq.redis = Travis::Logs.redis_pool
          ::Sidekiq.logger = ::Logger.new($stdout) if debug?

          %w[Aggregate Archive LogParts PartmanMaintenance Purge].each do |name|
            Travis::Logs::Sidekiq.const_get(name)
          end
        end

        def debug?
          Travis.config.log_level.to_s == 'debug'
        end
      end
    end
  end
end
