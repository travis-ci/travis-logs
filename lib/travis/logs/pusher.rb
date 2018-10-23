# frozen_string_literal: true

require 'pusher'
require 'multi_json'

require 'travis/logs'

module Travis
  module Logs
    class Pusher
      def initialize(pusher_client = nil)
        @pusher_client = pusher_client || default_client
      end

      def push(payload)
        pusher_channel(payload).trigger('job:log', pusher_payload(payload))
        if payload['queued_at']
          # TODO: deprecate this code path in favour of 'meta' below
          # https://github.com/travis-ci/reliability/issues/190
          elapsed = Time.now - Time.parse(payload['queued_at'])
          Metriks.timer('logs.time_to_first_log_line.pusher').update(elapsed)
        elsif payload['meta']
          meta = payload['meta']
          elapsed = Time.now - Time.parse(meta['queued_at'])
          Metriks.timer('logs.time_to_first_log_line.pusher').update(elapsed)
          Metriks.timer("logs.time_to_first_log_line.infra.#{meta['infra']}.pusher").update(elapsed)
          Metriks.timer("logs.time_to_first_log_line.queue.#{meta['queue']}.pusher").update(elapsed)
          Travis::Honeycomb.always_sample!
          Travis::Honeycomb.context.merge(
            time_to_first_log_line_pusher_ms: elapsed * 1000,
            infra: meta['infra'],
            queue: meta['queue'],
            repo:  meta['repo']
          )
        end
      end

      def pusher_channel_name(payload)
        "#{secure? ? 'private-' : ''}job-#{payload['id']}"
      end

      def webhook(request)
        @pusher_client.webhook(request)
      end

      private def pusher_channel(payload)
        @pusher_client[pusher_channel_name(payload)]
      end

      private def pusher_payload(payload)
        MultiJson.dump('id' => payload['id'],
                       '_log' => payload['chars'],
                       'number' => payload['number'],
                       'final' => payload['final'])
      end

      private def default_client
        ::Pusher::Client.new(Travis.config.pusher.to_h)
      end

      private def secure?
        Travis.config.pusher.secure
      end
    end
  end
end
