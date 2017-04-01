# frozen_string_literal: true

module Travis
  module Logs
    module Helpers
      class DatabaseVacuumSettings
        # These vacuum settings are meant to make autovacuuming much more
        # aggressive on the log_parts table than the defaults typically allow.
        STATEMENTS = [
          'ALTER TABLE log_parts
           SET (autovacuum_vacuum_threshold =
                %{log_parts_autovacuum_vacuum_threshold})',
          'ALTER TABLE log_parts
           SET (autovacuum_vacuum_scale_factor =
                %{log_parts_autovacuum_vacuum_scale_factor})',
          'ALTER DATABASE %{database}
           SET vacuum_cost_limit = %{vacuum_cost_limit}',
          'ALTER DATABASE %{database}
           SET vacuum_cost_delay = %{vacuum_cost_delay}'
        ].freeze
      end
    end
  end
end
