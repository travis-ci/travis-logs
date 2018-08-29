# frozen_string_literal: true

require 'pusher'

# pusher requires this in a method, which sometimes causes an uninitialized
# constant error
require 'net/https'

require 'travis/exceptions'

module Travis
  module Logs
    class PusherForwarder
      include Travis::Logs::MetricsMethods

      METRIKS_PREFIX = 'logs.process_log_part'

      def self.metriks_prefix
        METRIKS_PREFIX
      end

      def self.run(payload)
        new.run(payload)
      end

      def initialize(database: nil, pusher_client: nil, existence: nil,
                     log_parts_normalizer: nil)
        @database = database
        @pusher_client = pusher_client
        @existence = existence
        @log_parts_normalizer = log_parts_normalizer
      end

      private def database
        @database ||= Travis::Logs.database_connection
      end

      private def pusher_client
        @pusher_client ||= Travis::Logs::Pusher.new
      end

      private def existence
        @existence ||= Travis::Logs::Existence.new
      end

      private def log_parts_normalizer
        @log_parts_normalizer ||=
          Travis::Logs::Services::NormalizeLogParts.new(database: @database)
      end

      def run(payload)
        payload = [payload] if payload.is_a?(Hash)
        payload = Array(payload)

        measure do
          # rubocop:disable Performance/HashEachMethods
          log_parts_normalizer.run(payload).each do |_, entry|
            notify(entry)
          end
          # rubocop:enable Performance/HashEachMethods
        end
      end

      private def notify(entry)
        if existence_check_metrics? || existence_check?
          if channel_occupied?(channel_name(entry))
            mark('pusher.send')
          else
            mark('pusher.ignore')
            return if existence_check?
          end
        end
        measure('pusher') do
          pusher_client.push(pusher_payload(entry))
        end
      rescue StandardError => e
        Travis.logger.error(
          'Error notifying of log update',
          err: e.message, from: e.backtrace.first
        )
        Travis::Exceptions.handle(e)
      end

      private def final?(entry)
        !!entry['final'] # rubocop:disable Style/DoubleNegation
      end

      private def pusher_payload(entry)
        payload = {
          'id' => entry['id'],
          'chars' => Travis::Logs::ContentDecoder.decode_content(entry),
          'number' => entry['number'],
          'final' => final?(entry)
        }
        payload['received_at'] = entry['received_at'] if entry['received_at']
        payload
      end

      private def channel_occupied?(name)
        existence.occupied?(name)
      end

      private def channel_name(entry)
        pusher_client.pusher_channel_name(entry)
      end

      private def existence_check_metrics?
        Travis.config.channels_existence_metrics
      end

      private def existence_check?
        Travis.config.channels_existence_check
      end
    end
  end
end
