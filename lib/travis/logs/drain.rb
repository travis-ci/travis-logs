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
        1.upto(num_threads) { |n| spawn_thread_loop(n) }
        Travis.logger.info('drain threads spawned', n: num_threads)
        sleep
      end

      private def spawn_thread_loop(n)
        Travis.logger.debug('spawning drain thread', n: n)
        Travis::Logs::DrainQueue.subscribe(
          'logs',
          batch_handler: ->(batch) { handle_batch(batch) },
          pusher_handler: ->(payload) { forward_pusher_payload(payload) }
        )
      rescue Travis::Logs::DrainQueueShutdownError => e
        Travis::Exceptions.handle(e)
        retry
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
