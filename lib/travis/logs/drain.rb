# frozen_string_literal: true

require 'travis/exceptions'
require 'travis/logs'
require 'travis/metrics'

module Travis
  module Logs
    class Drain
      def self.setup
        return if defined?(@setup)
        Travis.logger.debug('setting up drain dependencies')
        Travis::Exceptions.setup(
          Travis.config, Travis.config.env, Travis.logger
        )
        Travis::Metrics.setup(Travis.config.metrics, Travis.logger)
        Travis::Logs::Sidekiq.setup
        @setup = true
      end

      def run(once: false)
        self.class.setup

        Travis.logger.debug(
          'setting up log parts drain consumers',
          count: consumer_count
        )

        1.upto(consumer_count) do |n|
          consumers["#{n}/#{consumer_count}"] = create_consumer
        end

        consumers.each_pair { |_, consumer| consumer.subscribe }

        return run_loop_tick if once
        loop { run_loop_tick }
      end

      def run_loop_tick
        dead = []
        consumers.each_pair do |name, consumer|
          Travis.logger.debug('checking drain consumer', name: name)
          if consumer.dead?
            dead << name
            Travis.logger.debug('dead consumer found', name: name)
          end
        end

        dead.each do |name|
          Travis.logger.debug('creating new consumer', name: name)
          consumers[name] = create_consumer
          consumers[name].subscribe
        end

        sleep(loop_sleep_interval)
      end

      private def consumers
        @consumers ||= Concurrent::Map.new
      end

      private def create_consumer
        Travis::Logs::DrainConsumer.new(
          # TODO: revert this before release!!!!
          'logs_sharded',
          batch_handler: ->(batch) { handle_batch(batch) },
          pusher_handler: ->(payload) { forward_pusher_payload(payload) }
        )
      end

      private def handle_batch(batch)
        Travis.logger.debug('received batch payload')
        Travis::Logs::Sidekiq::LogParts.perform_async(
          ensure_entries_base64(batch)
        )
      end

      private def forward_pusher_payload(payload)
        Travis::Logs::Sidekiq::PusherForwarding.perform_async(
          ensure_entries_base64([payload])
        )
      end

      private def ensure_entries_base64(batch)
        batch.map do |entry|
          if entry['encoding'] != 'base64'
            entry['log'] = Base64.strict_encode64(entry['log'])
            entry['encoding'] = 'base64'
          end
          entry
        end
      end

      private def consumer_count
        Travis.config.logs.drain_consumer_count
      end

      private def loop_sleep_interval
        Travis.config.logs.drain_loop_sleep_interval
      end
    end
  end
end
