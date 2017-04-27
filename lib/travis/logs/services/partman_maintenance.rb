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

        def self.run
          new.run
        end

        def run
          table_names.each do |table_name|
            measure(table_name) do
              Travis.logger.info(
                'running partman.run_maintenance',
                table: table_name
              )

              db.run("SET statement_timeout = #{statement_timeout_ms}")

              db[<<~SQL].to_a
                SELECT partman.run_maintenance(
                  '#{table_name}',
                  p_debug := true
                )
              SQL
            end
          end
        end

        private def db
          @db ||= Travis::Logs::Database.create_sequel
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
