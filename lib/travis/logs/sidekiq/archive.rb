require 'sidekiq'
require 'travis/logs/services/archive_logs'

module Travis
  module Logs
    module Sidekiq
      class Archive
        include Sidekiq::Worker

        sidekiq_options queue: 'archive'

        def perform(log_id)
          Services::ArchiveLogs.new(log_id).run
        end
      end
    end
  end
end