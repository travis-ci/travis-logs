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

        def run(log_id: nil, job_id: nil, after: nil, part_numbers: [], require_all: false, content: true)
          if job_id
            if ignored_job_id?(job_id)
              return temporarily_unavailable_log_parts
            elsif job_id < min_accepted_job_id
              return []
            end
          elsif log_id
            if ignored_log_id?(log_id)
              return temporarily_unavailable_log_parts(log_id: log_id)
            elsif log_id < min_accepted_id
              return []
            end
          end

          fetch(
            log_id: log_id,
            job_id: job_id,
            after: after,
            part_numbers: part_numbers,
            require_all: require_all,
            content: content
          )
        end

        private def fetch(
          log_id: nil, job_id: nil, after: nil, part_numbers: [], require_all: false, content: true
        )
          log_id = database.cached_log_id_for_job_id(job_id) if log_id.nil?
          return nil if log_id.nil?

          log = database.log_for_id(log_id)
          return log_aggregated(log_id) if log && log[:aggregated_at]

          result = database.log_parts(log_id, after: after, part_numbers: part_numbers, require_all: require_all, content: content)
          return temporarily_unavailable_log_parts(log_id: log_id) unless result

          result
        end

        private def min_accepted_job_id
          Travis.config.logs.archive_spoofing.min_accepted_job_id
        end

        private def min_accepted_id
          Travis.config.logs.archive_spoofing.min_accepted_id
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

        private def log_aggregated(log_id)
          [
            {
              number: 0,
              log_id: log_id,
              content: 'log aggregated'
            }
          ]
        end
      end
    end
  end
end
