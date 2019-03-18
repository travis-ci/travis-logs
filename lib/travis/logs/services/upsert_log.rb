# frozen_string_literal: true

require 'travis/logs'

module Travis
  module Logs
    module Services
      class UpsertLog
        def initialize(database: nil)
          @database = database || Travis::Logs.database_connection
        end

        attr_reader :database
        private :database

        def run(job_id: nil, content: '', removed_by: nil)
          job_id = Integer(job_id)
          log_id = find_or_create_log(job_id)

          content = content.to_s
          content = nil if content.empty?

          update_log(log_id, content, removed_by)
        end

        private def find_or_create_log(job_id)
          log_id = database.cached_log_id_for_job_id(job_id)
          return log_id if log_id

          database.create_log(job_id)
        end

        private def update_log(log_id, content, removed_by)
          database.set_log_content(log_id, content, removed_by: removed_by)
        end
      end
    end
  end
end
