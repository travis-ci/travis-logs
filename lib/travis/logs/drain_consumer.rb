# frozen_string_literal: true

require 'bunny'
require 'coder'
require 'concurrent'
require 'multi_json'
require 'sequel'
require 'travis/logs'

module Travis
  module Logs
    class DrainConsumer
      include Travis::Logs::MetricsMethods

      METRIKS_PREFIX = 'logs.queue'

      def self.metriks_prefix
        METRIKS_PREFIX
      end

      attr_reader :batch_buffer, :flush_mutex
      attr_reader :reporting_jobs_queue, :batch_handler
      attr_reader :pusher_handler, :periodic_flush_task
      private :batch_buffer
      private :flush_mutex
      private :batch_handler
      private :pusher_handler
      private :periodic_flush_task

      def initialize(batch_handler: nil, pusher_handler: nil)
        @batch_buffer = Concurrent::Map.new
        @flush_mutex = Mutex.new
        @batch_handler = batch_handler
        @pusher_handler = pusher_handler

        # initialize queue before building periodic flush task
        # to protect against race conditions
        jobs_queue

        @periodic_flush_task = build_periodic_flush_task
        @created_at = Time.now
      end

      def subscribe
        Travis.logger.debug('subscribing', queue: jobs_queue.name)

        jobs_queue.subscribe(manual_ack: true) do |*args|
          Travis::Honeycomb::RabbitMQ.call(self.class.name, *args, &method(:receive))
        end
      rescue Bunny::TCPConnectionFailedForAllHosts
        @dead = true
      end

      def dead?
        @dead == true || ack_timeout?
      end

      private def ack_timeout?
        # fall back to created_at
        # in case no messages were acked at all
        seconds_since_last_ack = Time.now - (@last_ack || @created_at)
        seconds_since_last_ack > logs_config[:drain_ack_timeout]
      end

      private def jobs_queue
        return jobs_queue_sharded if logs_config[:drain_rabbitmq_sharding]

        jobs_queue_single
      end

      private def jobs_queue_single
        @jobs_queue ||= jobs_channel.queue(
          'reporting.jobs.logs',
          durable: true, exclusive: false
        )
      end

      private def jobs_queue_sharded
        @jobs_queue ||= jobs_channel.queue(
          'reporting.jobs.logs_sharded',
          durable: true, exclusive: false, no_declare: true
        )
      end

      private def jobs_channel
        @jobs_channel ||= amqp_conn.create_channel.tap do |channel|
          channel.prefetch(Travis.config.amqp[:prefetch]) if Travis.config.amqp[:prefetch]
        end
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

      private def shutdown(reason)
        Travis.logger.debug('shutting down drain consumer', reason: reason)
        amqp_conn.close
      rescue StandardError => e
        Travis::Exceptions.handle(e)
      ensure
        @dead = true
        @batch_buffer = nil
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
        return ensure_shutdown if dead?
        return if batch_buffer.empty?

        Travis.logger.debug(
          'flushing batch buffer', size: batch_buffer.size,
                                   consumer: object_id
        )
        sample = {}
        payload = []
        batch_buffer.each_pair do |delivery_tag, entry|
          sample[delivery_tag] = entry
        end
        sample.each_pair do |delivery_tag, entry|
          payload.push(entry)
          batch_buffer.delete_pair(delivery_tag, entry)
        end
        batch_handler.call(payload)
        begin
          max_delivery_tag = sample.keys.max
          Travis.logger.debug(
            'ack-ing batched messages',
            max_delivery_tag: max_delivery_tag,
            consumer: object_id
          )
          safe_ack(max_delivery_tag, true)
        rescue StandardError => e
          sample.each_pair do |delivery_tag, entry|
            batch_buffer[delivery_tag] = entry
          end
          Travis.logger.error(
            'failed to ack message',
            error: e.inspect
          )
        end
      end

      private def receive(delivery_info, _properties, payload)
        return if dead?

        decoded_payload = nil
        decoded_payload = decode(payload)
        if decoded_payload
          pusher_handler.call(decoded_payload)
          batch_buffer[delivery_info.delivery_tag] = decoded_payload
          if batch_buffer.size >= batch_size
            Travis.logger.debug('batch size reached - triggering flush')
            Travis::Honeycomb.context.set('logs.drain.flush_batch', 1)
            flush_mutex.synchronize { flush_batch_buffer }
          end
        else
          Travis.logger.debug('acking empty or undecodable payload')
          safe_ack(delivery_info.delivery_tag, false)
        end
      rescue StandardError => e
        log_exception(e, decoded_payload)
        jobs_channel.reject(delivery_info.delivery_tag, true)
        mark('receive.retry')
        Travis.logger.error('message requeued', stage: 'queue:receive')
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

      private def safe_ack(delivery_tag, multiple)
        jobs_channel.ack(delivery_tag, multiple)
        @last_ack = Time.now
      rescue Bunny::Exception => e
        Travis.logger.error(
          'shutting down due to bunny exception',
          error: e.inspect
        )
        shutdown('safe_ack')
      end

      private def ensure_shutdown
        shutdown('dead') if dead? && !amqp_conn.closed?
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
