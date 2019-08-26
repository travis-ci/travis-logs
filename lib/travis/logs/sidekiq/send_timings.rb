# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq/worker'

require 'travis/logs'

module Travis
  module Logs
    module Sidekiq
      class SendTimings
        include ::Sidekiq::Worker

        sidekiq_options queue: 'send_timing', retry: 3,
                        unique: :until_and_while_executing

        def perform(log_id)
          Travis::Honeycomb.context.set('log_id', log_id)
          Travis::Logs::Services::SendTimings.new(log_id).run
        end
      end
    end
  end
end
