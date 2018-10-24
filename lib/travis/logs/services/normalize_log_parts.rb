# frozen_string_literal: true

require 'travis/logs'

module Travis
  module Logs
    module Services
      class NormalizeLogParts
        INT_MAX = 2_147_483_647

        def initialize(database: nil, log_finder: nil)
          @database = database
          @log_finder = log_finder
        end

        private def database
          @database ||= Travis::Logs.database_connection
        end

        private def log_finder
          @log_finder ||=
            Travis::Logs::Services::FindOrCreateLog.new(database: @database)
        end

        def run(log_parts)
          normalized_entries(log_parts)
        end

        private def normalized_entries(log_parts)
          mapped = log_parts.map do |entry|
            [
              log_finder.run(entry['id']),
              normalize_number(entry)
            ]
          end
          mapped.sort_by { |e| e.first.to_i }
        end

        private def normalize_number(entry)
          return entry.merge('number' => INT_MAX) if entry['number'] == 'last'

          entry.merge('number' => Integer(entry['number']))
        end
      end
    end
  end
end
