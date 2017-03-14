# frozen_string_literal: true
require 'coder'
require 'json'
require 'timeout'

module Travis
  module Logs
    class Receive
      class Queue
        include Logging

        METRIKS_PREFIX = 'logs.queue'

        def self.subscribe(name, handler)
          new(name, handler).subscribe
        end

        attr_reader :name, :handler

        def initialize(name, handler)
          @name = name
          @handler = handler
        end

        def subscribe
          consumer.subscribe(ack: true, declare: true, &method(:receive))
        end

        private

        def consumer
          Travis::Amqp::Consumer.jobs(name, channel: { prefetch: prefetch })
        end

        def prefetch
          Travis::Logs.config.amqp.prefetch
        end

        def receive(message, payload)
          decoded_payload = nil
          smart_retry do
            decoded_payload = decode(payload)
            if decoded_payload
              Travis.uuid = decoded_payload.delete('uuid')
              handler.run(decoded_payload)
            end
          end
          message.ack
        rescue => e
          log_exception(e, decoded_payload)
          message.reject(requeue: true)
          Metriks.meter("#{METRIKS_PREFIX}.receive.retry").mark
          error '[queue:receive] message requeued'
        end

        def smart_retry(&block)
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

        def decode(payload)
          return payload if payload.is_a?(Hash)
          payload = Coder.clean(payload)
          ::JSON.parse(payload)
        rescue StandardError => e
          error "[queue:decode] payload could not be decoded: #{e.inspect} #{payload.inspect}"
          Metriks.meter("#{METRIKS_PREFIX}.payload.decode_error").mark
          nil
        end

        def log_exception(error, payload)
          Travis.logger.error(
            'Exception caught in queue while processing payload',
            action: 'receive',
            queue: name,
            payload: payload.inspect
          )
          Travis::Exceptions.handle(error)
        rescue Exception => e
          Travis.logger.error("!!!FAILSAFE!!! #{e.message}")
          Travis.logger.error(e.backtrace.first)
        end
      end
    end
  end
end
