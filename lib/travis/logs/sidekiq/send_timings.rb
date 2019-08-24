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
          send_timings_service.send_timings(log_id)
        end

        private def send_timings_service
          @send_timings_service ||= Travis::Logs::Services::SendTimings.new
        end
      end
    end
  end
end
