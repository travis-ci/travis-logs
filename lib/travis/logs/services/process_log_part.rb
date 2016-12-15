require 'travis/logs/helpers/metrics'
require 'travis/logs/helpers/pusher'
require 'travis/logs/existence'
require 'pusher'
require 'coder'

# pusher requires this in a method, which sometimes
# causes and uninitialized constant error
require 'net/https'

module Travis
  module Logs
    module Services
      class ProcessLogPart
        include Helpers::Metrics

        METRIKS_PREFIX = 'logs.process_log_part'.freeze

        def self.metriks_prefix
          METRIKS_PREFIX
        end

        def self.run(payload)
          new(payload).run
        end

        attr_reader :payload

        def initialize(payload, database = nil, pusher_client = nil, existence = nil)
          @payload = payload
          @database = database || Travis::Logs.database_connection
          @pusher_client = pusher_client || Travis::Logs::Helpers::Pusher.new
          @existence = existence || Travis::Logs::Existence.new
        end

        def run
          measure do
            find_or_create_log
            create_part
            notify
          end
        end

        private

        attr_reader :database, :pusher_client, :existence

        def create_part
          valid_log_id?
          database.create_log_part(log_id: log_id, content: chars, number: number, final: final?)
        rescue Sequel::Error => e
          Travis.logger.warn "[warn] could not save log_park in create_part job_id: #{payload['id']}: #{e.message}"
          Travis.logger.warn e.backtrace
        end

        def valid_log_id?
          if log_id == 0
            Travis.logger.warn "action=process job_id=#{payload['id']} result=invalid_id log_id=#{log_id.inspect}"
            mark('log.id_invalid')
          end
        end

        def notify
          if existence_check_metrics? || existence_check?
            if channel_occupied?(channel_name)
              mark('pusher.send')
            else
              mark('pusher.ignore')

              return if existence_check?
            end
          end

          measure('pusher') do
            pusher_client.push(pusher_payload)
          end
        rescue => e
          Travis.logger.error("Error notifying of log update: #{e.message} (from #{e.backtrace.first})")
        end

        def log_id
          @log_id ||= find_log_id || create_log
        end
        alias find_or_create_log log_id

        def find_log_id
          database.log_id_for_job_id(payload['id'])
        end

        def create_log
          Travis.logger.warn "action=process job_id=#{payload['id']} message=log_created"
          mark('log.create')
          database.create_log(payload['id'])
        end

        def chars
          @chars ||= filter(payload['log'])
        end

        def number
          payload['number']
        end

        def final?
          !!payload['final']
        end

        def filter(chars)
          # postgres seems to have issues with null chars
          Coder.clean!(chars.to_s.delete("\0"))
        end

        def pusher_payload
          {
            'id' => payload['id'],
            'chars' => chars,
            'number' => number,
            'final' => final?
          }
        end

        def channel_occupied?(channel_name)
          existence.occupied?(channel_name)
        end

        def channel_name
          pusher_client.pusher_channel_name(payload)
        end

        def existence_check_metrics?
          Logs.config.channels_existence_metrics
        end

        def existence_check?
          Logs.config.channels_existence_check
        end
      end
    end
  end
end
