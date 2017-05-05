# frozen_string_literal: true

require 'travis/exceptions'
require 'travis/logs'
require 'travis/metrics'

module Travis
  module Logs
    class Drain
      def setup
        Travis::Exceptions.setup(
          Travis.config, Travis.config.env, Travis.logger
        )
        Travis::Metrics.setup(Travis.config.metrics, Travis.logger)
        Travis::Logs::Sidekiq.setup
      end

      def run
        1.upto(num_threads) do |n|
          Travis.logger.debug('spawning receiver thread', n: n)
          Travis::Logs::DrainQueue.subscribe(
            'logs',
            batch_handler: ->(batch) { handle_batch(batch) },
            pusher_handler: ->(payload) { forward_pusher_payload(payload) }
          )
        end
        Travis.logger.info('consumer threads spawned', n: num_threads)
        sleep
      end

      private def handle_batch(batch)
        Travis.logger.debug('received batch payload')
        Travis::Logs::Sidekiq::LogParts.perform_async(batch)
      end

      private def forward_pusher_payload(payload)
        Travis::Logs::Sidekiq::PusherForwarding.perform_async(payload)
      end

      private def num_threads
        Travis.config.logs.drain_threads
      end
    end
  end
end
