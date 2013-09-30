require 'sidekiq/worker'
require 'travis/logs/services/archive_log'

module Travis
  module Logs
    module Sidekiq
      class Archive
        include ::Sidekiq::Worker

        sidekiq_options queue: 'archive', retry: 3

        def perform(log_id)
          Services::ArchiveLog.new(log_id).run
        end
      end
    end
  end
end