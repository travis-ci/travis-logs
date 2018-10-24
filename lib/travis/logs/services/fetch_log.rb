# frozen_string_literal: true

module Travis
  module Logs
    module Services
      class FetchLog
        def initialize(database: nil)
          @database = database || Travis::Logs.database_connection
        end

        attr_reader :database
        private :database

        def run(job_id: nil, id: nil, aggregate_on_demand: true)
          return nil if job_id.nil? && id.nil?
          raise ArgumentError, 'only one of job_id or id allowed' if job_id && id

          if job_id
            if ignored_job_id?(job_id)
              return temporarily_unavailable_log(job_id: job_id)
            elsif job_id < min_accepted_job_id
              return spoofed_archived_log(job_id: job_id)
            end
          elsif id
            if ignored_log_id?(id)
              return temporarily_unavailable_log(id: id)
            elsif id < min_accepted_id
              return spoofed_archived_log(id: id)
            end
          end

          fetch(
            job_id: job_id,
            id: id,
            aggregate_on_demand: aggregate_on_demand
          )
        end

        private def fetch(job_id: nil, id: nil, aggregate_on_demand: true)
          result = nil
          result = database.log_for_job_id(job_id) if job_id
          result = database.log_for_id(id) if id
          return nil if result.nil?

          content       = result[:content]
          aggregated_at = result[:aggregated_at]
          if aggregate_on_demand && (aggregated_at.nil? || content.nil?)
            content = [
              content, database.aggregated_on_demand(result[:id])
            ].join('')
            content = nil if content.strip.empty?
          end
          removed_by_id = result.delete(:removed_by)
          result.merge(
            content: content,
            removed_by_id: removed_by_id
          )
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

        private def spoofed_archived_log(job_id: nil, id: nil)
          {
            aggregated_at: Time.now - 300,
            archive_verified: true,
            archived_at: Time.now - 300,
            content: nil,
            id: id,
            job_id: job_id,
            removed_at: nil,
            removed_by: nil,
            updated_at: Time.now
          }
        end

        private def temporarily_unavailable_log(job_id: nil, id: nil)
          spoofed_archived_log(job_id: job_id, id: id).merge(
            archived_at: nil,
            archive_verified: false,
            content: 'Your log is temporarily unavailable'
          )
        end
      end
    end
  end
end
