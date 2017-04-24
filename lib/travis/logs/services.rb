# frozen_string_literal: true

module Travis
  module Logs
    module Services
      autoload :AggregateLogs, 'travis/logs/services/aggregate_logs'
      autoload :ArchiveLog, 'travis/logs/services/archive_log'
      autoload :FetchLog, 'travis/logs/services/fetch_log'
      autoload :FetchLogParts, 'travis/logs/services/fetch_log_parts'
      autoload :ProcessLogPart, 'travis/logs/services/process_log_part'
      autoload :PurgeLog, 'travis/logs/services/purge_log'
      autoload :UpsertLog, 'travis/logs/services/upsert_log'
    end
  end
end
