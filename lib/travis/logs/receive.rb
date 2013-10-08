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
        Travis::Logs::Helpers::Reporting.setup
        Travis::Exceptions::Reporter.start

        db = Travis::Logs::Helpers::Database.connect
        Logs.database_connection = db
      end

      def run
        1.upto(Logs.config.logs.threads) do
          Queue.subscribe('logs', Travis::Logs::Services::ProcessLogPart)
        end
      end
    end
  end
end
