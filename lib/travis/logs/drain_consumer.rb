# frozen_string_literal: true

require 'bunny'
require 'coder'
require 'concurrent'
require 'multi_json'
require 'thread'
require 'timeout'

require 'travis/logs'

module Travis
  module Logs
    class DrainConsumer
      include Travis::Logs::MetricsMethods

      METRIKS_PREFIX = 'logs.queue'

      def self.metriks_prefix
        METRIKS_PREFIX
      end

      attr_reader :reporting_jobs_queue, :batch_handler
      attr_reader :pusher_handler, :periodic_flush_task
      private :batch_handler
      private :pusher_handler
      private :periodic_flush_task

      def initialize(reporting_jobs_queue, batch_handler: nil,
                     pusher_handler: nil)
        @reporting_jobs_queue = reporting_jobs_queue
        @batch_handler = batch_handler
        @pusher_handler = pusher_handler
        @periodic_flush_task = build_periodic_flush_task
      end

      def subscribe
        Travis.logger.info('subscribing', queue: jobs_queue.name)
        jobs_queue.subscribe(manual_ack: true, &method(:receive))
      end

      def dead?
        @dead == true
      end

      private def jobs_queue
        @jobs_queue ||= jobs_channel.queue(
          "reporting.jobs.#{reporting_jobs_queue}",
          durable: true, exclusive: false
        )
      end

      private def jobs_channel
        @jobs_channel ||= amqp_conn.create_channel
      end

      private def batch_size
        @batch_size ||= Integer(logs_config[:drain_batch_size] || 0)
      end

      private def amqp_conn
        @amqp_conn ||= Bunny.new(Travis.config.amqp).tap(&:start)
      end

      private def logs_config
        @logs_config ||= Travis.config.logs.to_h
      end

      private def batch_buffer
        @batch_buffer ||= Concurrent::Map.new
      end

      private def flush_mutex
        @flush_mutex ||= Mutex.new
      end

      private def shutdown
        jobs_channel.close
        amqp_conn.close
      rescue StandardError => e
        Travis::Exceptions.handle(e)
      ensure
        @jobs_channel = nil
        @amqp_conn = nil
        @dead = true
        sleep
      end

      private def build_periodic_flush_task
        Concurrent::TimerTask.execute(
          run_now: true,
          execution_interval: logs_config[:drain_execution_interval],
          timeout_interval: logs_config[:drain_timeout_interval]
        ) do
          Travis.logger.debug(
            'triggering periodic flush',
            drain_queue: reporting_jobs_queue,
            interval: "#{logs_config[:drain_execution_interval]}s",
            timeout: "#{logs_config[:drain_timeout_interval]}s"
          )
          flush_mutex.synchronize { flush_batch_buffer }
        end
      end

      private def flush_batch_buffer
        Travis.logger.info(
          'flushing batch buffer', size: batch_buffer.size
        )
        sample = {}
        payload = []

        batch_buffer.each_pair do |delivery_tag, entry|
          sample[delivery_tag] = entry
        end

        sample.each_pair do |delivery_tag, entry|
          payload.push(entry)

          begin
            batch_buffer.delete_pair(delivery_tag, entry)
          rescue StandardError => e
            Travis.logger.error(
              'failed to delete pair from buffer',
              error: e.inspect
            )
            payload.pop
            next
          end

          begin
            safe_ack(delivery_tag)
          rescue StandardError => e
            Travis.logger.error(
              'failed to ack message',
              error: e.inspect
            )
            payload.pop
            batch_buffer[delivery_tag] = entry
          end
        end

        batch_handler.call(payload) unless payload.empty?
      end

      private def receive(delivery_info, _properties, payload)
        return if dead?
        decoded_payload = nil
        smart_retry do
          decoded_payload = decode(payload)
          if decoded_payload
            pusher_handler.call(decoded_payload)
            batch_buffer[delivery_info.delivery_tag] = decoded_payload
            if batch_buffer.size >= batch_size
              flush_mutex.synchronize { flush_batch_buffer }
            end
          else
            Travis.logger.info('acking empty or undecodable payload')
            safe_ack(delivery_info.delivery_tag)
          end
        end
      rescue => e
        log_exception(e, decoded_payload)
        jobs_channel.reject(delivery_info.delivery_tag, true)
        mark('receive.retry')
        Travis.logger.error('message requeued', stage: 'queue:receive')
      end

      private def smart_retry(retries: 2, timeout: 3, &block)
        retry_count = 0
        begin
          Timeout.timeout(timeout, &block)
        rescue Timeout::Error, Sequel::PoolTimeout
          if retry_count < retries
            retry_count += 1
            Travis.logger.error(
              'processing AMQP message timeout exceeded',
              action: 'receive',
              timeout_seconds: timeout,
              retry: retry_count,
              max_retries: retries
            )
            mark('timeout.retry')
            retry
          else
            Travis.logger.error(
              'failed to process AMQP message, aborting',
              action: 'receive',
              max_retries: retries
            )
            mark('timeout.error')
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
          'payload could not be decoded',
          error: e.inspect,
          payload: payload.inspect,
          stage: 'queue:decode'
        )
        mark('payload.decode_error')
        nil
      end

      private def safe_ack(delivery_tag)
        jobs_channel.ack(delivery_tag)
      rescue Bunny::Exception => e
        Travis.logger.error(
          'shutting down due to bunny exception',
          error: e.inspect
        )
        shutdown
      end

      private def log_exception(error, payload)
        Travis.logger.error(
          'exception caught in queue while processing payload',
          action: 'receive',
          queue: reporting_jobs_queue,
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
