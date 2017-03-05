module Travis
  module Logs
    module Services
      class FetchLog
        def initialize(database: nil, spoof_archived_cutoffs: {})
          @database = database || Travis::Logs.database_connection
          @spoof_archived_cutoffs = {
            log_id: Integer(spoof_archived_cutoffs.fetch(:log_id)).abs,
            job_id: Integer(spoof_archived_cutoffs.fetch(:job_id)).abs
          }
        end

        attr_reader :database, :spoof_archived_cutoffs
        private :database
        private :spoof_archived_cutoffs

        def run(job_id: nil, id: nil)
          return nil if job_id.nil? && id.nil?
          if job_id && id
            raise ArgumentError, 'only one of job_id or id allowed'
          end

          if spoof_archived?(job_id, id)
            return spoofed_archived_result(job_id, id)
          end

          result = nil
          result = database.log_for_job_id(job_id) if job_id
          result = database.log_for_id(id) if id
          return nil if result.nil?

          content = result[:content]

          if result[:aggregated_at].nil?
            content = [
              content, database.aggregated_on_demand(result[:id])
            ].join('')
          end

          removed_by_id = result.delete(:removed_by)
          result.merge(
            content: content,
            aggregated_at: result[:updated_at] || Time.now.utc - 60,
            removed_by_id: removed_by_id
          )
        end

        private def spoof_archived?(job_id, id)
          return spoof_archived_cutoffs.fetch(:log_id) > id unless id.nil?
          spoof_archived_cutoffs.fetch(:job_id) > job_id
        end

        private def spoofed_archived_result(job_id, id)
          {
            id: id,
            job_id: job_id,
            content: nil,
            archived_at: Time.now.utc - 60,
            archive_verified: true
          }
        end
      end
    end
  end
end
