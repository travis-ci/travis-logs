require 'travis/logs'
require 'travis/support'
require 'travis/support/amqp'
require 'travis/support/exceptions/reporter'
require 'travis/logs/receive/queue'
require 'travis/logs/services/process_log_part'
require 'travis/logs/helpers/database'
require 'travis/logs/helpers/reporting'
require 'active_support/core_ext/logger'

$stdout.sync = true

module Travis
  module Logs
    class Receive
      def setup
        Travis.logger.info('** Starting Log Parts Processor **')
        Travis::Amqp.config = Travis::Logs.config.amqp
        Travis::Logs::Helpers::Database.setup
        Travis::Logs::Helpers::Reporting.setup
        Travis::Exceptions::Reporter.start
      end

      def run
        1.upto(Logs.config.logs.threads) do
          Queue.subscribe('logs', &method(:receive))
        end
      end

      def receive(payload)
        Travis::Logs::Services::ProcessLogPart.run(payload)
      end
    end
  end
end
