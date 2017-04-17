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
          if job_id && id
            raise ArgumentError, 'only one of job_id or id allowed'
          end

          if job_id && job_id < database.job_id_min_readable
            return spoofed_archived_log(job_id: job_id)
          end

          if id && id < database.log_id_min_readable
            return spoofed_archived_log(id: id)
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

          content = result[:content]

          if aggregate_on_demand && result[:aggregated_at].nil?
            content = [
              content, database.aggregated_on_demand(result[:id])
            ].join('')
          end

          removed_by_id = result.delete(:removed_by)
          result.merge(
            content: content,
            removed_by_id: removed_by_id
          )
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
      end
    end
  end
end
