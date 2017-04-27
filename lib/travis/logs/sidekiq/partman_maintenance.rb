# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq/worker'

require 'travis/logs'

module Travis
  module Logs
    module Sidekiq
      class PartmanMaintenance
        include ::Sidekiq::Worker

        sidekiq_options queue: 'maintenance', dead: false, retry: false

        def perform(*)
          Travis::Logs::Services::PartmanMaintenance.run
        end
      end
    end
  end
end
