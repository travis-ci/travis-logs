# frozen_string_literal: true

require 'active_support/core_ext/object/deep_dup'

module Travis
  module Honeycomb
    module RabbitMQ
      class << self
        def call(worker_name, delivery_info, properties, payload)
          unless Travis::Honeycomb.enabled?
            yield delivery_info, properties, payload
            return
          end

          Travis::Honeycomb.context.clear

          Travis::Honeycomb.context.tags(
            request_type:  'rabbitmq',
            request_shape: worker_name
          )

          queue_time = nil
          queue_time = Time.now - properties.timestamp if properties.timestamp

          request_started_at = Time.now
          begin
            yield delivery_info, properties, payload

            request_ended_at = Time.now
            request_time = request_ended_at - request_started_at

            honeycomb(worker_name, delivery_info, properties, payload, request_time, queue_time)
          rescue StandardError => e
            request_ended_at = Time.now
            request_time = request_ended_at - request_started_at

            honeycomb(worker_name, delivery_info, properties, payload, request_time, queue_time, e)

            raise
          end
        end

        private def honeycomb(_worker_name, delivery_info, properties, payload, request_time, queue_time, e = nil)
          event = {}
          event = event.merge(Travis::Honeycomb.context.data)
          delivery = delivery_info.to_hash.dup
          delivery.delete(:delivery_tag)
          delivery.delete(:consumer)
          delivery.delete(:channel)
          delivery[:delivery_tag] = delivery_info.delivery_tag
          event = event.merge(
            rabbitmq: {
              bytes:      payload.bytesize,
              properties: properties.to_hash,
              delivery:   delivery
            },
            request_duration_ms: request_time * 1000,
            request_queue_ms:    queue_time * 1000,
            exception_class:     e&.class&.name,
            exception_message:   e&.message,
            exception_backtrace: e&.backtrace,
            prev_exception_class:     e&.cause&.class&.name,
            prev_exception_message:   e&.cause&.message,
            prev_exception_backtrace: e&.cause&.backtrace
          )
          # remove nil and blank values
          event = event.reject { |_k, v| v.nil? || v == '' }
          Travis::Honeycomb.send(event)
        end
      end
    end
  end
end
