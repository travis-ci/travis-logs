require 'uri'
require 'travis/logs'
require 'travis/support'
require 'travis/support/amqp'
require 'travis/support/exceptions/reporter'
require 'travis/support/metrics'
require 'travis/logs/receive/queue'
require 'travis/logs/services/process_log_part'
require 'travis/logs/helpers/database'
require 'active_support/core_ext/logger'

$stdout.sync = true

module Travis
  module Logs
    class Receive
      def setup
        Travis.logger.info('** Starting Log Parts Processor **')
        Travis::Amqp.config = amqp_config
        Travis::Exceptions::Reporter.start
        Travis::Metrics.setup

        db = Travis::Logs::Helpers::Database.connect
        Logs.database_connection = db

        declare_exchanges
        :alldone
      end

      def run
        1.upto(Logs.config.logs.threads) do
          Queue.subscribe('logs', Travis::Logs::Services::ProcessLogPart)
        end
        sleep
      end

      def amqp_config
        url = URI(Travis::Logs.config.amqp.fetch(:url))

        Travis::Logs.config.amqp.merge(
          thread_pool_size: (Logs.config.logs.threads * 2 + 3),
          host: url.hostname,
          vhost: url.path.delete('/'),
          port: url.port,
          username: url.user,
          password: url.password
        )
      end

      def declare_exchanges
        channel = Travis::Amqp.connection.create_channel
        channel.topic('reporting', durable: true, auto_delete: false)
      end
    end
  end
end
