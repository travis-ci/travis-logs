module Travis
  module Logs
    module Services
      class FetchLog
        def initialize(database: nil)
          @database = database || Travis::Logs.database_connection
        end

        attr_reader :database
        private :database

        def run(job_id: nil)
          return nil if job_id.nil?

          result = database.log_for_job_id(job_id)
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
