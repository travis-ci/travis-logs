# frozen_string_literal: true

require 'travis/honeycomb'
require 'active_support/core_ext/object/deep_dup'

module Travis
  module Logs
    module Sidekiq
      class Honeycomb
        def call(worker, job, queue)
          Travis::Honeycomb.clear

          unless Travis::Honeycomb.enabled?
            yield
            return
          end

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

          job = job.deep_dup
          job.delete('args')

          event = event.merge({
            sidekiq_job:  job,

            sidekiq_job_duration_ms: request_time * 1000,
            sidekiq_job_queue_ms:    queue_time * 1000,

            exception_class:         e&.class&.name,
            exception_message:       e&.message,
            exception_cause_class:   e&.cause&.class&.name,
            exception_cause_message: e&.cause&.message,
          })

          # remove nil and blank values
          event = event.reject { |k,v| v.nil? || v == '' }

          Travis::Honeycomb.send(event)
        end
      end
    end
  end
end
