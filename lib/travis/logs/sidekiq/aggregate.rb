require 'sidekiq/worker'
require 'travis/logs/services/aggregate_logs'

module Travis
  module Logs
    module Sidekiq
      class Aggregate
        include ::Sidekiq::Worker

        sidekiq_options queue: 'aggregate', retry: 3

        def perform(log_part_ids)
          Services::AggregateLogs.aggregate_ids(log_part_ids)
        end
      end
    end
  end
end
