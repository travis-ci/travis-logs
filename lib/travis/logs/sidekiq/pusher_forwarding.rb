# frozen_string_literal: true

require 'sidekiq/worker'

require 'travis/logs'

module Travis
  module Logs
    module Sidekiq
      class PusherForwarding
        class << self
          def pusher_forwarder
            @pusher_forwarder ||= Travis::Logs::PusherForwarder.new
          end
        end

        include ::Sidekiq::Worker

        sidekiq_options queue: 'logs.pusher_forwarding', retry: 3

        def perform(payload)
          Travis.logger.debug('running with payload')
          self.class.pusher_forwarder.run(payload)
        end
      end
    end
  end
end
