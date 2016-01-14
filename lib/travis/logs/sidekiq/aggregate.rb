require 'sidekiq/worker'
require 'travis/logs/services/aggregate_logs'

module Travis
  module Logs
    module Sidekiq
      class Aggregate
        include ::Sidekiq::Worker

        sidekiq_options queue: 'aggregate', retry: 3,
                        unique: :until_and_while_executing

        def perform(log_id)
          Travis::Logs::Services::AggregateLogs.aggregate_log(log_id)
        end
      end
    end
  end
end
