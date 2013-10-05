require 'travis/logs/helpers/metrics'
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

        METRIKS_PREFIX = "logs.process_log_part"

        def self.metriks_prefix
          METRIKS_PREFIX
        end

        def self.run(payload)
          new(payload).run
        end

        attr_reader :payload

        def initialize(payload, database = Travis::Logs.database_connection)
          @payload = payload
          @database = database
        end

        def run
          measure do
            find_or_create_log
            create_part
            notify
          end
        end

        private

          attr_reader :database

          def create_part
            valid_log_id?
            database.create_log_part(log_id: log_id, content: chars, number: number, final: final?)
          rescue Sequel::Error => e
            Travis.logger.warn "[warn] could not save log_park in create_part job_id: #{payload['id']}: #{e.message}"
            Travis.logger.warn e.backtrace
          end

          def valid_log_id?
            if log_id == 0
              Travis.logger.warn "[warn] log.id is #{log_id.inspect} in create_part (job_id: #{payload['id']})"
              mark('log.id_invalid')
            end
          end

          def notify
            measure('pusher') do
              Logs.config.pusher_client[pusher_channel].trigger('job:log', pusher_payload)
            end
          rescue => e
            Travis.logger.error("Error notifying of log update: #{e.message} (from #{e.backtrace.first})")
          end

          def log_id
            @log_id ||= find_log_id || create_log
          end
          alias_method :find_or_create_log, :log_id

          def find_log_id
            log = database.log_for_job_id(payload["id"])
            log ? log[:id] : nil
          end

          def create_log
            Travis.logger.warn "Had to create a log for job_id: #{payload['id']}!"
            mark('log.create')
            database.create_log(payload["id"])
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
            Coder.clean!(chars.to_s.gsub("\0", ''))
          end

          def pusher_channel
            channel = ""
            channel << "private-" if Logs.config.pusher.secure
            channel << "job-#{payload['id']}"
            channel
          end

          def pusher_payload
            {
              'id' => payload['id'],
              '_log' => chars,
              'number' => number,
              'final' => final?
            }
          end
      end
    end
  end
end
