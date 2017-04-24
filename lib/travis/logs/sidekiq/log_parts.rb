# frozen_string_literal: true

require 'sidekiq/worker'

require 'travis/logs'

module Travis
  module Logs
    module Sidekiq
      class LogParts
        include ::Sidekiq::Worker

        sidekiq_options queue: 'log_parts', retry: 3

        def perform(payload)
          Travis.logger.debug('running with payload')
          log_part_processor.run(payload)
        end

        private def log_part_processor
          @log_part_processor ||= Travis::Logs::Services::ProcessLogPart.new
        end
      end
    end
  end
end
