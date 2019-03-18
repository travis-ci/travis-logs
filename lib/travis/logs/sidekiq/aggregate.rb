# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq/worker'

require 'travis/logs'

module Travis
  module Logs
    module Sidekiq
      class Aggregate
        include ::Sidekiq::Worker

        sidekiq_options queue: 'aggregate', retry: 3,
                        unique: :until_and_while_executing

        def perform(log_id)
          Travis::Honeycomb.context.set('log_id', log_id)
          aggregate_logs_service.aggregate_log(log_id)
        end

        private def aggregate_logs_service
          @aggregate_logs_service ||= Travis::Logs::Services::AggregateLogs.new
        end
      end
    end
  end
end
