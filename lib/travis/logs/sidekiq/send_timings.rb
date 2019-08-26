# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq/worker'

require 'travis/logs'

module Travis
  module Logs
    module Sidekiq
      class SendTimings
        include ::Sidekiq::Worker

        sidekiq_options queue: 'send_timings', retry: 3,
                        unique: :until_and_while_executing

        def perform(job_id)
          Travis::Honeycomb.context.set('job_id', job_id)
          Travis::Logs::Services::SendTimings.new(job_id).run
        end
      end
    end
  end
end
