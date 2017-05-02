# frozen_string_literal: true

require 'travis/logs'

module Travis
  module Logs
    module Services
      class FindOrCreateLog
        include Travis::Logs::MetricsMethods

        METRIKS_PREFIX = 'logs.process_log_part'

        def self.metriks_prefix
          METRIKS_PREFIX
        end

        def initialize(database: nil)
          @database = database || Travis::Logs.database_connection
        end

        attr_reader :database
        private :database

        def run(job_id)
          find_log_id(job_id) || create_log(job_id)
        end

        private def find_log_id(job_id)
          database.cached_log_id_for_job_id(job_id)
        end

        private def create_log(job_id)
          mark('log.create')
          created = database.create_log(job_id)
          Travis.logger.warn(
            'created log',
            action: 'process', job_id: job_id, message: 'log_created'
          )
          created
        end
      end
    end
  end
end
