module Travis
  module Logs
    module Services
      class FetchLog
        def initialize(database: nil)
          @database = database || Travis::Logs.database_connection
        end

        attr_reader :database
        private :database

        def run(job_id: nil, id: nil)
          return nil if job_id.nil? && id.nil?
          if job_id && id
            raise ArgumentError, 'only one of job_id or id allowed'
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

          result.merge(content: content)
        end
      end
    end
  end
end
