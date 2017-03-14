# frozen_string_literal: true
require 'travis/logs/helpers/metrics'
require 'travis/logs/helpers/pusher'
require 'travis/logs/existence'
require 'travis/logs/sidekiq/aggregate'
require 'pusher'
require 'coder'

# pusher requires this in a method, which sometimes causes an uninitialized
# constant error
require 'net/https'

module Travis
  module Logs
    module Services
      class ProcessLogPart
        include Helpers::Metrics

        METRIKS_PREFIX = 'logs.process_log_part'
        INT_MAX = 9_223_372_036_854_775_807

        def self.metriks_prefix
          METRIKS_PREFIX
        end

        def self.run(payload)
          new.run(payload)
        end

        def initialize(database: nil, pusher_client: nil,
                       existence: nil)
          @database = database || Travis::Logs.database_connection
          @pusher_client = pusher_client || Travis::Logs::Helpers::Pusher.new
          @existence = existence || Travis::Logs::Existence.new
        end

        def run(payload)
          measure do
            log_id = find_or_create_log(payload)
            payload = normalize_number(payload)
            create_part(log_id, payload)
            notify(payload)
          end
        end

        attr_reader :database, :pusher_client, :existence
        private :database
        private :pusher_client
        private :existence

        private def create_part(log_id, payload)
          valid_log_id?(log_id, payload)
          database.create_log_part(
            log_id: log_id,
            content: chars(payload),
            number: payload['number'],
            final: final?(payload)
          )
          aggregate_async(log_id, payload) if final?(payload)
        rescue Sequel::Error => e
          Travis.logger.warn(
            'Could not save log_part in create_part',
            job_id: payload['id'], warning: e.message
          )
          Travis.logger.warn(e.backtrace.join("\n"))
        end

        private def valid_log_id?(log_id, payload)
          if log_id == 0
            Travis.logger.warn(
              'invalid log id',
              action: 'process', job_id: payload['id'],
              result: 'invalid_id', log_id: log_id
            )
            mark('log.id_invalid')
          end
        end

        private def notify(payload)
          if existence_check_metrics? || existence_check?
            if channel_occupied?(channel_name(payload))
              mark('pusher.send')
            else
              mark('pusher.ignore')

              return if existence_check?
            end
          end

          measure('pusher') do
            pusher_client.push(pusher_payload(payload))
          end
        rescue => e
          Travis.logger.error(
            'Error notifying of log update',
            err: e.message, from: e.backtrace.first
          )
        end

        private def aggregate_async(log_id, payload)
          Travis.logger.info(
            'scheduling async aggregation',
            job_id: payload['id'], log_id: log_id
          )
          Travis::Logs::Sidekiq::Aggregate.perform_in(
            intervals[:regular], log_id
          )
        end

        private def find_or_create_log(payload)
          find_log_id(payload) || create_log(payload)
        end

        private def normalize_number(payload)
          if payload['number'] == 'last'
            return payload.merge('number' => INT_MAX)
          end
          payload.merge('number' => Integer(payload['number']))
        end

        private def find_log_id(payload)
          database.log_id_for_job_id(payload['id'])
        end

        private def create_log(payload)
          mark('log.create')
          created = database.create_log(payload['id'])
          Travis.logger.warn(
            'created log',
            action: 'process', job_id: payload['id'], message: 'log_created'
          )
          created
        end

        private def chars(payload)
          filter(payload['log'])
        end

        private def final?(payload)
          !!payload['final'] # rubocop:disable Style/DoubleNegation
        end

        private def filter(chars)
          # postgres seems to have issues with null chars
          Coder.clean!(chars.to_s.delete("\0"))
        end

        private def pusher_payload(payload)
          {
            'id' => payload['id'],
            'chars' => chars(payload),
            'number' => payload['number'],
            'final' => final?(payload)
          }
        end

        private def channel_occupied?(name)
          existence.occupied?(name)
        end

        private def channel_name(payload)
          pusher_client.pusher_channel_name(payload)
        end

        private def existence_check_metrics?
          Travis::Logs.config.channels_existence_metrics
        end

        private def existence_check?
          Travis::Logs.config.channels_existence_check
        end

        private def intervals
          Travis.config.logs.intervals
        end
      end
    end
  end
end
