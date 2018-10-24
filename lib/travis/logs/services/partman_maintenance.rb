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
          run_analyze
        end

        private def run_maintenance
          setup_connection
          sleep(initial_sleep)
          cancel_conflicting_backends
          terminate_conflicting_backends!
          table_names.each do |table_name|
            measure("maintenance.#{table_name}") do
              Travis.logger.info(
                'running partman.run_maintenance',
                table: table_name
              )
              db[<<~SQL].to_a
                SELECT partman.run_maintenance(
                  '#{table_name}',
                  p_debug := true,
                  p_analyze := false
                )
              SQL
            end
          end
        end

        private def run_analyze
          table_names.each do |table_name|
            measure("analyze.#{table_name}") do
              Travis.logger.info(
                'running analyze',
                table: table_name
              )
              db[<<~SQL].to_a
                ANALYZE #{table_name}
              SQL
            end
          end
        end

        def setup_connection
          db.run("SET statement_timeout = #{statement_timeout_ms}")
          db.run("SET application_name = 'partman_maintenance'")
          db.run('SET client_min_messages = DEBUG5')
        end

        LOGS_QUERIES_SQL = <<~SQL
          SELECT pid
          FROM pg_stat_activity
          WHERE application_name ~ '^logs\..+'
            AND query ~ '.+log_parts.+'
            AND query !~ '.+pg_stat_activity.+'
        SQL
        private_constant :LOGS_QUERIES_SQL

        CANCEL_LOGS_QUERIES_SQL = <<~SQL
          SELECT pg_cancel_backend(q.pid)
          FROM (#{LOGS_QUERIES_SQL}) q
        SQL
        private_constant :CANCEL_LOGS_QUERIES_SQL

        TERMINATE_LOGS_QUERIES_SQL = <<~SQL
          SELECT pg_terminate_backend(q.pid)
          FROM (#{LOGS_QUERIES_SQL}) q
        SQL
        private_constant :TERMINATE_LOGS_QUERIES_SQL

        private def cancel_conflicting_backends
          backoff_loop { db[CANCEL_LOGS_QUERIES_SQL].to_a.empty? }
        end

        private def terminate_conflicting_backends!
          backoff_loop { db[TERMINATE_LOGS_QUERIES_SQL].to_a.empty? }
        end

        private def backoff_loop(loops: 3)
          i = 1
          loop do
            break if yield

            sleep(i**i)
            i += 1
            break if i >= loops
          end
        end

        private def db
          @db ||= Travis::Logs::Database.create_sequel
        end

        private def initial_sleep
          Travis.config.logs.maintenance_initial_sleep
        end

        private def statement_timeout_ms
          (initial_sleep + maint.expiry + 5.minutes) * 1000
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
