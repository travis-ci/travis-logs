require 'sidekiq/worker'
require 'travis/logs/services/purge_log'

module Travis
  module Logs
    module Sidekiq
      class Purge
        include ::Sidekiq::Worker

        sidekiq_options queue: 'purge_log', retry: 3

        def perform(log_id)
          Services::PurgeLog.new(log_id).run
        end
      end
    end
  end
end