# frozen_string_literal: true

module Travis
  module Logs
    module Services
      class PartmanMaintenance
        include Travis::Logs::MetricsMethods

        METRIKS_PREFIX = 'logs.partman_maintenance'

        def self.metriks_prefix
          METRIKS_PREFIX
        end

        def self.run(maint: Travis::Logs::Maintenance.new)
          new(maint: maint).run
        end

        def initialize(maint: Travis::Logs::Maintenance.new)
          @maint = maint
        end

        attr_reader :maint
        private :maint

        def run
          maint.with_maintenance_on { run_maintenance }
        end

        private def run_maintenance
          setup_connection
          sleep(initial_sleep)
          terminate_conflicting_backends!

          table_names.each do |table_name|
            measure(table_name) do
              Travis.logger.info(
                'running partman.run_maintenance',
                table: table_name
              )

              db[<<~SQL].to_a
                SELECT partman.run_maintenance(
                  '#{table_name}',
                  p_debug := true
                )
              SQL
            end
          end
        end

        def setup_connection
          db.run("SET statement_timeout = #{statement_timeout_ms}")
          db.run("SET application_name = 'partman_maintenance'")
        end

        TERMINATE_LOGS_WRITE_QUERIES_SQL = <<~SQL
          SELECT pg_terminate_backend(q.pid)
          FROM (
            SELECT pid
            FROM pg_stat_activity
            WHERE application_name ~ '^logs\..+'
          ) q
        SQL
        private_constant :TERMINATE_LOGS_WRITE_QUERIES_SQL

        private def terminate_conflicting_backends!(loops: 3)
          i = 1
          loop do
            break if i >= loops
            results = db[TERMINATE_LOGS_WRITE_QUERIES_SQL].to_a
            break if results.empty?
            i += 1
          end
        end

        private def db
          @db ||= Travis::Logs::Database.create_sequel
        end

        private def initial_sleep
          Travis.config.logs.maintenance_initial_sleep
        end

        private def statement_timeout_ms
          Travis.config.logs.maintenance_statement_timeout_ms
        end

        private def table_names
          %w[
            public.log_parts
          ]
        end
      end
    end
  end
end
