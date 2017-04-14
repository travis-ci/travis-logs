# frozen_string_literal: true

require 'bunny'
require 'coder'
require 'multi_json'
require 'timeout'

require 'travis/logs'

module Travis
  module Logs
    class DrainQueue
      METRIKS_PREFIX = 'logs.queue'

      def self.subscribe(name, &handler_callable)
        new(name, &handler_callable).subscribe
      end

      attr_reader :name, :handler_callable

      def initialize(name, &handler_callable)
        @name = name
        @handler_callable = handler_callable
      end

      def subscribe
        jobs_queue.subscribe(manual_ack: true, &method(:receive))
      end

      private def jobs_queue
        @jobs_queue ||= jobs_channel.queue(
          "reporting.jobs.#{name}", durable: true, exclusive: false
        )
      end

      private def jobs_channel
        @jobs_channel ||= amqp_conn.create_channel
      end

      private def amqp_conn
        @amqp_conn ||= Bunny.new(amqp_config).tap(&:start)
      end

      private def amqp_config
        Travis.config.amqp.to_h
      end

      private def receive(delivery_info, _properties, payload)
        decoded_payload = nil
        smart_retry do
          decoded_payload = decode(payload)
          if decoded_payload
            Thread.current[:uuid] = decoded_payload.delete('uuid')
            handler_callable.call(decoded_payload)
          end
        end
        jobs_channel.ack(delivery_info.delivery_tag, true)
      rescue => e
        log_exception(e, decoded_payload)
        jobs_channel.reject(delivery_info.delivery_tag, true)
        Metriks.meter("#{METRIKS_PREFIX}.receive.retry").mark
        Travis.logger.error('message requeued', stage: 'queue:receive')
      end

      private def smart_retry(&block)
        retry_count = 0
        begin
          Timeout.timeout(3, &block)
        rescue Timeout::Error, Sequel::PoolTimeout
          if retry_count < 2
            retry_count += 1
            Travis.logger.error(
              'Processing of AMQP message exceeded 3 seconds',
              action: 'receive',
              retry: retry_count,
              max_retries: 2
            )
            Metriks.meter("#{METRIKS_PREFIX}.timeout.retry").mark
            retry
          else
            Travis.logger.error(
              'Failed to process AMQP message after 3 retries, aborting',
              action: 'receive'
            )
            Metriks.meter("#{METRIKS_PREFIX}.timeout.error").mark
            raise
          end
        end
      end

      private def decode(payload)
        return payload if payload.is_a?(Hash)
        payload = Coder.clean(payload)
        MultiJson.load(payload)
      rescue StandardError => e
        Travis.logger.error(
          "payload could not be decoded: #{e.inspect} #{payload.inspect}",
          stage: 'queue:decode'
        )
        Metriks.meter("#{METRIKS_PREFIX}.payload.decode_error").mark
        nil
      end

      private def log_exception(error, payload)
        Travis.logger.error(
          'Exception caught in queue while processing payload',
          action: 'receive',
          queue: name,
          payload: payload.inspect
        )
        Travis::Exceptions.handle(error)
      rescue StandardError => e
        Travis.logger.error("!!!FAILSAFE!!! #{e.message}")
        Travis.logger.error(e.backtrace.first)
      end
    end
  end
end
