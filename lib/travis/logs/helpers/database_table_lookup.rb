module Travis
  module Logs
    module Helpers
      class DatabaseTableLookup
        INT_MAX = 2_147_483_647
        DEFAULT_MAPPING = {
          logs: {
            log_id: {
              [0, INT_MAX] => :logs
            },
            job_id: {
              [0, INT_MAX] => :logs
            }
          },
          log_parts: {
            log_id: {
              [0, INT_MAX] => :log_parts
            },
            active: :log_parts
          }
        }.freeze

        def initialize(mapping: nil)
          @mapping = mapping || DEFAULT_MAPPING
        end

        attr_reader :mapping
        private :mapping

        def logs_table_for_log_id(log_id)
          find_between(mapping[:logs][:log_id], log_id)
        end

        def logs_table_for_job_id(job_id)
          find_between(mapping[:logs][:job_id], job_id)
        end

        def logs_tables
          mapping[:logs].map { |_, v| v.values }.flatten.compact.uniq
        end

        def log_parts_tables
          mapping[:log_parts].map do |k, v|
            next if k == :active
            v.values
          end.flatten.compact.uniq
        end

        def log_parts_table_for_log_id(log_id)
          find_between(mapping[:log_parts][:log_id], log_id)
        end

        def active_log_parts_table
          mapping[:log_parts].fetch(:active)
        end

        private def find_between(lookup, id)
          lookup.find { |(f, c), _| id.between?(f, c) }.fetch(1)
        end
      end
    end
  end
end
