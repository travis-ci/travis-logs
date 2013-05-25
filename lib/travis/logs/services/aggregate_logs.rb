require 'active_support/core_ext/string/filters'
require 'travis/logs/models/log'
require 'travis/logs/models/log_part'
require 'travis/logs/sidekiq'

module Travis
  module Logs
    module Services
      class AggregateLogs
        METRIKS_PREFIX = "logs.aggregate_logs"

        AGGREGATE_UPDATE_SQL = <<-sql.squish
          UPDATE logs
             SET aggregated_at = ?,
                 content = (COALESCE(content, '') || (#{Log::AGGREGATE_PARTS_SELECT_SQL}))
           WHERE logs.id = ?
        sql

        AGGREGATEABLE_SELECT_SQL = <<-sql.squish
          SELECT DISTINCT log_id
            FROM log_parts
           WHERE created_at <= NOW() - interval '? seconds' AND final = ?
              OR created_at <= NOW() - interval '? seconds'
        sql

        def self.run
          new.run
        end

        def run
          aggregateable_ids.each do |id|
            transaction do
              aggregate(id)
              vacuum(id)
              queue_archiving(id)
            end
          end
        end

        private

          def aggregate(id)
            measure('aggregate') do
              connection.execute(sanitize_sql([AGGREGATE_UPDATE_SQL, Time.now, id, id]))
            end
          end

          def vacuum(id)
            measure('vacuum') do
              LogPart.delete_all(log_id: id)
            end
          end

          def queue_archiving(id)
            log = Log.find(id)
            Logs::Sidekiq.queue_archive_job({ id: log.id, job_id: log.job_id, type: 'log' })
          rescue ActiveRecord::RecordNotFound
            mark('log.record_not_found')
            Travis.logger.warn "could not find a log with the id #{id}"
          end

          def aggregateable_ids
            connection.select_values(query).map { |id| id.nil? ? id : id.to_i }
          end

          def query
            LogPart.send(:sanitize_sql, [AGGREGATEABLE_SELECT_SQL, intervals[:regular], true, intervals[:force]])
          end

          def intervals
            Travis.config.logs.intervals
          end

          def transaction(&block)
            measure do
              ActiveRecord::Base.transaction(&block)
            end
          rescue ActiveRecord::ActiveRecordError => e
            Travis::Exceptions.handle(e)
          end

          def connection
            LogPart.connection
          end

          def sanitize_sql(*args)
            LogPart.send(:sanitize_sql, *args)
          end

          def measure(name=nil, &block)
            timer_name = [METRIKS_PREFIX, name].compact.join('.')
            Metriks.timer(timer_name).time(&block)
          rescue => e
            failed_name = [name, 'failed'].compact.join('.')
            mark(failed_name)
            raise
          end

          def mark(name)
            Metriks.meter("#{METRIKS_PREFIX}.#{name}").mark
          end
      end
    end
  end
end

