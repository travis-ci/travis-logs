# frozen_string_literal: true

require 'travis/logs'

module Travis
  module Logs
    module Sidekiq
      class LogParts
        class << self
          def log_parts_writer
            @log_parts_writer ||= Travis::Logs::LogPartsWriter.new
          end
        end

        include ::Sidekiq::Worker

        sidekiq_options queue: 'log_parts', retry: 3

        def perform(payload)
          Travis.logger.debug('running with payload')
          self.class.log_parts_writer.run(payload)
        end
      end
    end
  end
end
