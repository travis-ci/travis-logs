require 'travis/logs/models/log'
require 'travis/logs/models/log_part'
require 'pusher'
require 'coder'

module Travis
  module Logs
    module Services
      class ProcessLogPart
        def self.run(payload)
          new(payload).run
        end

        attr_reader :payload

        def initialize(payload)
          @payload = payload
        end

        def run
          create_part
          notify
        end

        private

          def create_part
            measure('logs.update') do
              Travis.logger.warn "[warn] log.id is #{log.id.inspect} in :logs_append! job_id: #{payload['id']}" if log.id.to_i == 0
              LogPart.create!(log_id: log.id, content: chars, number: number, final: final?)
            end
          rescue ActiveRecord::ActiveRecordError => e
            Travis.logger.warn "[warn] could not save log in :logs_append job_id: #{payload['id']}: #{e.message}"
            Travis.logger.warn e.backtrace
          end

          def notify
            Logs.config.pusher_client["job-#{payload['id']}"].trigger('job:log', pusher_payload)
          rescue => e
            Metriks.meter('travis.logs.update.notify.errors').mark
            Travis.logger.error("Error notifying of log update: #{e.message} (from #{e.backtrace.first})")
          end

          def log
            @log ||= Log.where(job_id: payload['id']).select(:id).first || create_log
          end

          def create_log
            Travis.logger.warn "[warn] Had to create a log for job_id: #{payload['id']}!"
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
            Coder.clean!(chars.to_s.gsub("\0", '')) # postgres seems to have issues with null chars
          end

          def measure(name, &block)
            Metriks.timer(name).time(&block)
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
