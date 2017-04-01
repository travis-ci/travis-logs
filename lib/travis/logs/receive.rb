# frozen_string_literal: true

require 'travis/logs'
require 'travis/support'
require 'travis/support/exceptions/reporter'
require 'travis/support/metrics'
require 'travis/logs/receive/queue'
require 'travis/logs/services/process_log_part'
require 'travis/logs/helpers/database'
require 'travis/logs/sidekiq'
require 'active_support/core_ext/logger'

module Travis
  module Logs
    class Receive
      def setup
        Travis.logger.info('Starting Log Parts Processor')
        Travis::Exceptions::Reporter.start
        Travis::Metrics.setup
        Travis::Logs::Sidekiq.setup
      end

      def run
        1.upto(Travis::Logs.config.logs.threads) do
          Travis::Logs::Receive::Queue.subscribe(
            'logs', Travis::Logs::Services::ProcessLogPart.new
          )
        end
      end
    end
  end
end
