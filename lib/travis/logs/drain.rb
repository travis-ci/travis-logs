# frozen_string_literal: true

require 'travis/exceptions'
require 'travis/logs'
require 'travis/logs/helpers/database'
require 'travis/logs/drain_queue'
require 'travis/logs/services/process_log_part'
require 'travis/logs/sidekiq'
require 'travis/logs/sidekiq/log_parts'
require 'travis/metrics'

module Travis
  module Logs
    class Drain
      def setup
        Travis::Exceptions.setup(
          Travis.config, Travis.config.env, Travis.logger
        )
        Travis::Metrics.setup(Travis.config, Travis.logger)
        Travis::Logs::Sidekiq.setup
      end

      def run
        1.upto(Travis::Logs.config.logs.threads) do |n|
          Travis.logger.debug('spawning receiver thread', n: n)
          Travis::Logs::DrainQueue.subscribe('logs') do |payload|
            receive(payload)
          end
        end
        Travis.logger.info(
          'consumer threads spawned',
          n: Travis::Logs.config.logs.threads
        )
        sleep
      end

      private def receive(payload)
        Travis.logger.debug('received payload')
        Travis::Logs::Sidekiq::LogParts.perform_async(payload)
      end
    end
  end
end
