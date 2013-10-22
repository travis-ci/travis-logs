require 'active_support/core_ext/string/filters'
require 'travis/logs/helpers/metrics'
require 'travis/logs/sidekiq/archive'

module Travis
  module Logs
    module Services
      class AggregateLogs
        include Helpers::Metrics

        METRIKS_PREFIX = "logs.aggregate_logs"

        def self.metriks_prefix
          METRIKS_PREFIX
        end

        def self.prepare(db)
          # DB['SELECT * FROM table WHERE a = ?', :$a].prepare(:all, :ps_name).call(:a=>1)
          # do not use prepared queries for the time being
        end

        def self.run
          new.run
        end

        def initialize(database = nil)
          @database = database || Travis::Logs.database_connection
        end

        def run
          aggregateable_ids.each do |id|
            aggregate_log(id)
          end
        end

        private
          attr_reader :database

          def aggregate_log(id)
            transaction do
              aggregate(id)
              assert_not_empty(id)
              vacuum(id)
            end
            queue_archiving(id)
            Travis.logger.info "Finished aggregating Log with id:#{id}"
          rescue => e
            Travis::Exceptions.handle(e)
          end

          def aggregate(id)
            measure('aggregate') do
              database.aggregate(id)
            end
          end

          def assert_not_empty(id)
            log = database.log_for_id(id)
            if log.content.empty?
              fail "Log #{id} is empty, not vacuuming the log parts."
            end
          end

          def vacuum(id)
            measure('vacuum') do
              database.delete_log_parts(id)
            end
          end

          def queue_archiving(id)
            return unless Travis::Logs.config.logs.archive

            log = database.log_for_id(id)

            if log
              Sidekiq::Archive.perform_async(log[:id])
            else
              mark('log.record_not_found')
              Travis.logger.warn "Could not queue Log with id:#{id} for archiving as it could not be found"
            end
          end

          def aggregateable_ids
            database.aggregatable_log_parts(intervals[:regular], intervals[:force])
          end

          def intervals
            Travis.config.logs.intervals
          end

          def transaction(&block)
            measure do
              database.transaction(&block)
            end
          end
      end
    end
  end
end

