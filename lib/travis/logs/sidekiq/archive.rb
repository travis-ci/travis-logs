# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq/worker'

require 'travis/logs'

module Travis
  module Logs
    module Sidekiq
      class Archive
        include ::Sidekiq::Worker

        sidekiq_options queue: 'archive', retry: 3

        def perform(log_id)
          Travis::Honeycomb.context.set('log_id', log_id)
          Travis::Logs::Services::ArchiveLog.new(log_id).run
        end
      end
    end
  end
end
