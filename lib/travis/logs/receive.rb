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
        Travis::Exceptions::Reporter.start
        Travis::Metrics.setup
        Travis::Logs::Sidekiq.setup
      end

      def run
        1.upto(Travis::Logs.config.logs.threads) do |n|
          Travis.logger.debug('spawning receiver thread', n: n)
          Travis::Logs::Receive::Queue.subscribe(
            'logs',
            ->(p) { Travis::Logs::Sidekiq::LogParts.perform_async(p) }
          )
        end
        Travis.logger.info(
          'consumer threads spawned',
          n: Travis::Logs.config.logs.threads
        )
        sleep
      end
    end
  end
end
