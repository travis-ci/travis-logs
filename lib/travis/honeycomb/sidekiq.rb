# frozen_string_literal: true

require 'active_support/core_ext/object/deep_dup'

module Travis
  module Honeycomb
    module Sidekiq
      def call(worker, job, queue)
        unless Travis::Honeycomb.enabled?
          yield
          return
        end

        Travis::Honeycomb.clear

        queue_time = Time.now - Time.at(job['enqueued_at'])

        request_started_at = Time.now
        begin
          yield

          request_ended_at = Time.now
          request_time = request_ended_at - request_started_at

          honeycomb(worker, job, queue, request_time, queue_time)
        rescue => e
          request_ended_at = Time.now
          request_time = request_ended_at - request_started_at

          honeycomb(worker, job, queue, request_time, queue_time, e)

          raise
        end
      end

      private def honeycomb(worker, job, queue, request_time, queue_time, e = nil)
        event = {}

        event = event.merge(Travis::Honeycomb.context.data)

        event = event.merge({
          sidekiq_job: {
            class: job['class'],
            jid:   job['jid'],
            queue: job['queue'],
          },

          request_type:        'sidekiq',
          request_shape:       job['class'],
          request_duration_ms: request_time * 1000,
          request_queue_ms:    queue_time * 1000,

          exception_class:     e&.class&.name,
          exception_message:   e&.message,
          exception_backtrace: e&.backtrace,

          prev_exception_class:     e&.cause&.class&.name,
          prev_exception_message:   e&.cause&.message,
          prev_exception_backtrace: e&.cause&.backtrace,
        })

        # remove nil and blank values
        event = event.reject { |k,v| v.nil? || v == '' }

        Travis::Honeycomb.send(event)
      end
    end
  end
end
