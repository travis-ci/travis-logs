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
        queue = Travis::Logs::DrainQueue.new(
          'logs',
          batch_handler: ->(batch) { handle_batch(batch) },
          pusher_handler: ->(payload) { forward_pusher_payload(payload) }
        )
        Travis.logger.info('subscribing')
        queue.subscribe
      end

      private def handle_batch(batch)
        Travis.logger.debug('received batch payload')
        Travis::Logs::Sidekiq::LogParts.perform_async(batch)
      end

      private def forward_pusher_payload(payload)
        Travis::Logs::Sidekiq::PusherForwarding.perform_async(payload)
      end
    end
  end
end
