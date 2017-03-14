# frozen_string_literal: true
require 'travis/logs'
require 'travis/support'
require 'travis/amqp'
require 'travis/support/exceptions/reporter'
require 'travis/support/metrics'
require 'travis/logs/receive/queue'
require 'travis/logs/services/process_log_part'
require 'travis/logs/helpers/database'
require 'travis/logs/helpers/database_table_lookup'
require 'travis/logs/sidekiq'
require 'active_support/core_ext/logger'

module Travis
  module Logs
    class Receive
      def setup
        Travis.logger.info('Starting Log Parts Processor')
        Travis::Amqp.setup(amqp_config)
        Travis::Exceptions::Reporter.start
        Travis::Metrics.setup
        Travis::Logs::Sidekiq.setup

        db = Travis::Logs::Helpers::Database.connect(
          table_lookup: Travis::Logs::Helpers::DatabaseTableLookup.new(
            mapping: Travis::Logs.config.logs.table_lookup_mapping.to_h
          )
        )
        Travis::Logs.database_connection = db

        declare_exchanges
      end

      def run
        1.upto(Travis::Logs.config.logs.threads) do
          Travis::Logs::Receive::Queue.subscribe(
            'logs', Travis::Logs::Services::ProcessLogPart.new
          )
        end
      end

      def amqp_config
        Travis::Logs.config.amqp.to_h.merge(
          thread_pool_size: (Travis::Logs.config.logs.threads * 2 + 3)
        )
      end

      def declare_exchanges
        channel = Travis::Amqp.connection.create_channel
        channel.exchange(
          'reporting',
          durable: true,
          auto_delete: false,
          type: :topic
        )
      end
    end
  end
end
