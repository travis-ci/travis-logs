require 'travis/logs/models/log'
require 'travis/logs/models/log_part'
require 'pusher'
require 'coder'

module Travis
  module Logs
    module Services
      class ProcessLogPart
        METRIKS_PREFIX = "logs.process_log_part"

        def self.run(payload)
          new(payload).run
        end

        attr_reader :payload

        def initialize(payload)
          @payload = payload
        end

        def run
          measure do
            find_or_create_log
            create_part
            notify
          end
        end

        private

          def create_part
            valid_log_id?
            LogPart.create!(log_id: log.id, content: chars, number: number, final: final?)
          rescue ActiveRecord::ActiveRecordError => e
            Travis.logger.warn "[warn] could not save log_park in create_part job_id: #{payload['id']}: #{e.message}"
            Travis.logger.warn e.backtrace
          end

          def valid_log_id?
            if log.id.to_i == 0
              Travis.logger.warn "[warn] log.id is #{log.id.inspect} in create_part (job_id: #{payload['id']})" 
              mark('log.id_invalid')
            end
          end

          def notify
            measure('pusher') do
              Logs.config.pusher_client["job-#{payload['id']}"].trigger('job:log', pusher_payload)
            end
          rescue => e
            Travis.logger.error("Error notifying of log update: #{e.message} (from #{e.backtrace.first})")
          end

          def log
            @log ||= find_log || create_log
          end
          alias_method :find_or_create_log, :log

          def find_log
            Log.where(job_id: payload['id']).select(:id).first
          end

          def create_log
            Travis.logger.warn "Had to create a log for job_id: #{payload['id']}!"
            mark('log.create')
            Log.create!(job_id: payload['id'])
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

          def measure(name=nil, &block)
            timer_name = [METRIKS_PREFIX, name].compact.join('.')
            Metriks.timer(timer_name).time(&block)
          rescue => e
            failed_name = [name, 'failed'].compact.join('.')
            mark(failed_name)
            raise
          end

          def mark(name)
            Metriks.meter("#{METRIKS_PREFIX}.#{name}").mark
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
