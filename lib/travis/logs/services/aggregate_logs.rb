require 'active_support/core_ext/string/filters'
require 'travis/logs/helpers/metrics'
require 'travis/logs/sidekiq'

module Travis
  module Logs
    module Services
      class AggregateLogs
        include Helpers::Metrics

        METRIKS_PREFIX = "logs.aggregate_logs"

        AGGREGATE_PARTS_SELECT_SQL = <<-sql.squish
          SELECT array_to_string(array_agg(log_parts.content ORDER BY number, id), '')
            FROM log_parts
           WHERE log_id = ?
        sql

        AGGREGATE_UPDATE_SQL = <<-sql.squish
          UPDATE logs
             SET aggregated_at = ?,
                 content = (COALESCE(content, '') || (#{AGGREGATE_PARTS_SELECT_SQL}))
           WHERE logs.id = ?
        sql

        AGGREGATEABLE_SELECT_SQL = <<-sql.squish
          SELECT DISTINCT log_id
            FROM log_parts
           WHERE (created_at <= NOW() - interval '? seconds' AND final = ?)
              OR  created_at <= NOW() - interval '? seconds'
        sql

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

        def run
          aggregateable_ids.each do |id|
            transaction do
              aggregate(id)
              vacuum(id)
              queue_archiving(id)
              Travis.logger.info "Finished aggregating Log with id:#{id}"
            end
          end
        end

        private

          def aggregate(id)
            measure('aggregate') do
              connection[AGGREGATE_UPDATE_SQL, Time.now, id, id].update
            end
          end

          def vacuum(id)
            measure('vacuum') do
              connection[:log_parts].where(log_id: id).delete
            end
          end

          def queue_archiving(id)
            return unless Travis::Logs.config.logs.archive

            log = connection[:logs].select(:id, :job_id).first(id: id)

            if log
              Logs::Sidekiq.queue_archive_job({ id: log[:id], job_id: log[:job_id], type: 'log' })
            else
              mark('log.record_not_found')
              Travis.logger.warn "Could not queue Log with id:#{id} for archiving as it could not be found"
            end
          end

          def aggregateable_ids
            connection[AGGREGATEABLE_SELECT_SQL, intervals[:regular], true, intervals[:force]].map(:log_id)
          end

          def intervals
            Travis.config.logs.intervals
          end

          def transaction(&block)
            measure do
              connection.transaction(&block)
            end
          rescue Sequel::Error => e
            Travis::Exceptions.handle(e)
          end

          def connection
            Travis::Logs.database_connection
          end
      end
    end
  end
end

