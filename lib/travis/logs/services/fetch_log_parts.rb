# frozen_string_literal: true

module Travis
  module Logs
    module Services
      class FetchLogParts
        def initialize(database: nil)
          @database = database || Travis::Logs.database_connection
        end

        attr_reader :database
        private :database

        def run(log_id: nil, job_id: nil, after: nil, part_numbers: [])
          if job_id
            if ignored_job_id?(job_id)
              return temporarily_unavailable_log_parts
            elsif job_id < database.job_id_min_readable
              return []
            end
          elsif log_id
            if ignored_log_id?(log_id)
              return temporarily_unavailable_log_parts(log_id: log_id)
            elsif log_id < database.log_id_min_readable
              return []
            end
          end

          fetch(
            log_id: log_id,
            job_id: job_id,
            after: after,
            part_numbers: part_numbers
          )
        end

        private def fetch(
          log_id: nil, job_id: nil, after: nil, part_numbers: []
        )
          log_id = database.cached_log_id_for_job_id(job_id) if log_id.nil?
          return nil if log_id.nil?
          database.log_parts(log_id, after: after, part_numbers: part_numbers)
        end

        private def ignored_job_id?(job_id)
          Travis::Logs.redis.sismember('logs:ignored-job-ids', job_id.to_s)
        end

        private def ignored_log_id?(id)
          Travis::Logs.redis.sismember('logs:ignored-log-ids', id.to_s)
        end

        private def temporarily_unavailable_log_parts(log_id: nil)
          [
            {
              number: 0,
              log_id: log_id,
              content: 'Your log is temporarily unavailable'
            }
          ]
        end
      end
    end
  end
end
