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
        1.upto(Travis::Logs.config.logs.threads) do
          Queue.subscribe('logs', Travis::Logs::Services::ProcessLogPart)
        end
        sleep
      end

      def amqp_config
        amqp_config_hash = Travis::Logs.config.amqp.to_h
        url = URI(amqp_config_hash.fetch(:url))
        vhost = url.path.delete('/')
        vhost = '/' if vhost.empty?

        amqp_config_hash.merge(
          thread_pool_size: (Travis::Logs.config.logs.threads * 2 + 3),
          host: url.hostname,
          vhost: vhost,
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
