require 'coder'
require 'json'
require 'timeout'

module Travis
  module Logs
    class Receive
      class Queue
        include Logging

        METRIKS_PREFIX = 'logs.queue'.freeze

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
          smart_retry do
            payload = decode(payload)
            if payload
              Travis.uuid = payload.delete('uuid')
              handler.run(payload)
            end
          end
          message.ack
        rescue => e
          log_exception(e, payload)
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
              Travis.logger.error "[queue] Processing of AMQP message exceeded 3 seconds, retrying #{retry_count} of 2"
              Metriks.meter("#{METRIKS_PREFIX}.timeout.retry").mark
              retry
            else
              Travis.logger.error '[queue] Failed to process AMQP message after 3 retries, aborting'
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
          Travis.logger.error "[queue] Exception caught in queue #{name.inspect} while processing #{payload.inspect}"
          Travis::Exceptions.handle(error)
        rescue Exception => e
          Travis.logger.error "!!!FAILSAFE!!! #{e.message}"
          Travis.logger.error e.backtrace.first
        end
      end
    end
  end
end
