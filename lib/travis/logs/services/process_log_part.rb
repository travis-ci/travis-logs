# frozen_string_literal: true

require 'pusher'
require 'coder'

# pusher requires this in a method, which sometimes causes an uninitialized
# constant error
require 'net/https'

require 'travis/exceptions'

module Travis
  module Logs
    module Services
      class ProcessLogPart
        include Travis::Logs::MetricsMethods

        METRIKS_PREFIX = 'logs.process_log_part'
        INT_MAX = 2_147_483_647

        def self.metriks_prefix
          METRIKS_PREFIX
        end

        def self.run(payload)
          new.run(payload)
        end

        def initialize(database: nil, pusher_client: nil,
                       existence: nil)
          @database = database || Travis::Logs.database_connection
          @pusher_client = pusher_client || Travis::Logs::Pusher.new
          @existence = existence || Travis::Logs::Existence.new
        end

        def run(payload)
          payload = [payload] if payload.is_a?(Hash)
          payload = Array(payload)

          measure do
            by_log_id = normalized_entries(payload)
            create_parts(by_log_id)
            by_log_id.each { |_, entry| notify(entry) }
          end
        end

        attr_reader :database, :pusher_client, :existence
        private :database
        private :pusher_client
        private :existence

        private def normalized_entries(payload)
          mapped = payload.map do |entry|
            [
              find_or_create_log(entry),
              normalize_number(entry)
            ]
          end
          mapped.sort_by { |e| e.first.to_i }
        end

        private def create_parts(by_log_id)
          by_log_id.reject! do |log_id, entry|
            if log_id.nil? || log_id.zero?
              mark_invalid_log_id(log_id, entry)
              true
            else
              false
            end
          end

          entries = by_log_id.map do |log_id, entry|
            {
              log_id: log_id,
              content: chars(entry),
              number: entry['number'],
              final: final?(entry)
            }
          end

          database.create_log_parts(entries)

          by_log_id.each do |log_id, entry|
            aggregate_async(log_id, entry) if final?(entry)
          end
        rescue Sequel::Error => e
          Travis.logger.error(
            'Could not save log parts in create_parts',
            error: e.message
          )
          Travis::Exceptions.handle(e)
          raise
        end

        private def mark_invalid_log_id(log_id, entry)
          Travis.logger.warn(
            'invalid log id',
            action: 'process', job_id: entry['id'],
            result: 'invalid_id', log_id: log_id
          )
          mark('log.id_invalid')
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
          raise
        end

        private def aggregate_async(log_id, entry)
          Travis::Logs::Sidekiq::Aggregate.perform_in(
            intervals[:regular], log_id
          )
          Travis.logger.info(
            'scheduled async aggregation',
            job_id: entry['id'], log_id: log_id,
            in_seconds: intervals[:regular]
          )
        end

        private def find_or_create_log(entry)
          find_log_id(entry) || create_log(entry)
        end

        private def normalize_number(entry)
          return entry.merge('number' => INT_MAX) if entry['number'] == 'last'
          entry.merge('number' => Integer(entry['number']))
        end

        private def find_log_id(entry)
          database.log_id_for_job_id(entry['id'])
        end

        private def create_log(entry)
          mark('log.create')
          created = database.create_log(entry['id'])
          Travis.logger.warn(
            'created log',
            action: 'process', job_id: entry['id'], message: 'log_created'
          )
          created
        end

        private def chars(entry)
          filter(entry['log'])
        end

        private def final?(entry)
          !!entry['final'] # rubocop:disable Style/DoubleNegation
        end

        private def filter(chars)
          # postgres seems to have issues with null chars
          Coder.clean!(chars.to_s.delete("\0"))
        end

        private def pusher_payload(entry)
          {
            'id' => entry['id'],
            'chars' => chars(entry),
            'number' => entry['number'],
            'final' => final?(entry)
          }
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

        private def intervals
          Travis.config.logs.intervals
        end
      end
    end
  end
end
