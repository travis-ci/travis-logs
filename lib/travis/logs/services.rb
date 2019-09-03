# frozen_string_literal: true

module Travis
  module Logs
    module Services
      autoload :AggregateLogs, 'travis/logs/services/aggregate_logs'
      autoload :ArchiveLog, 'travis/logs/services/archive_log'
      autoload :FetchLog, 'travis/logs/services/fetch_log'
      autoload :FetchLogParts, 'travis/logs/services/fetch_log_parts'
      autoload :FindOrCreateLog, 'travis/logs/services/find_or_create_log'
      autoload :NormalizeLogParts, 'travis/logs/services/normalize_log_parts'
      autoload :PartmanMaintenance, 'travis/logs/services/partman_maintenance'
      autoload :PurgeLog, 'travis/logs/services/purge_log'
      autoload :TimingInfo, 'travis/logs/services/timing_info'
      autoload :UpsertLog, 'travis/logs/services/upsert_log'
    end
  end
end
