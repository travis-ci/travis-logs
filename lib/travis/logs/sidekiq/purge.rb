# frozen_string_literal: true

require 'sidekiq/worker'

require 'travis/logs'

module Travis
  module Logs
    module Sidekiq
      class Purge
        include ::Sidekiq::Worker

        sidekiq_options queue: 'purge_log', retry: 3

        def perform(log_id)
          Travis::Honeycomb.context.set('log_id', log_id)
          Travis::Logs::Services::PurgeLog.new(log_id).run
        end
      end
    end
  end
end
