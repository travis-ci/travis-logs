# frozen_string_literal: true

require 'concurrent'

require 'travis/logs'

module Travis
  module Logs
    module Services
      class AggregateLogs
        include Travis::Logs::MetricsMethods

        METRIKS_PREFIX = 'logs.aggregate_logs'

        def self.metriks_prefix
          METRIKS_PREFIX
        end

        def self.run
          new.run
        end

        def self.aggregate_log(log_id)
          new.aggregate_log(log_id)
        end

        def initialize(database = nil, pool_config = {})
          @database = database || Travis::Logs.database_connection
          @pool_config = if pool_config.empty?
                           Travis.config.logs.aggregate_pool.to_h
                         else
                           pool_config
                         end
        end

        def run
          Travis.logger.debug('fetching aggregatable ids')

          ids = aggregatable_ids
          if ids.empty?
            Travis.logger.debug('no aggregatable ids')
            return
          end

          Travis.logger.debug(
            'aggregating with pool config',
            pool_config.merge(action: 'aggregate')
          )
          Travis.logger.debug(
            'starting aggregation batch',
            size: ids.length, action: 'aggregate',
            'sample#aggregatable-logs': ids.length
          )

          pool = Concurrent::ThreadPoolExecutor.new(pool_config)
          ids.each { |i| pool.post { aggregate_log(i) } }
          pool.shutdown
          pool.wait_for_termination

          Travis.logger.debug(
            'finished aggregation batch',
            size: ids.length, action: 'aggregate'
          )
        end

        def run_ranges(cursor, per_page)
          cursor ||= database.min_log_part_id

          Travis.logger.debug('fetching aggregatable ids', cursor: cursor)
          ids = database.aggregatable_logs_page(cursor, per_page)

          if ids.empty?
            # Travis.logger.info('no aggregatable ids')
            return cursor + per_page
          end

          Travis.logger.debug(
            'aggregating with pool config',
            pool_config.merge(action: 'aggregate')
          )
          Travis.logger.debug(
            'starting aggregation batch',
            action: 'aggregate', 'sample#aggregatable-logs': ids.length
          )

          pool = Concurrent::ThreadPoolExecutor.new(pool_config)
          ids.each { |i| pool.post { aggregate_log(i) } }
          pool.shutdown
          pool.wait_for_termination

          Travis.logger.debug('finished aggregation batch', action: 'aggregate')
          cursor + per_page
        end

        def aggregate_log(log_id)
          measure do
            database.db.transaction do
              aggregate(log_id)
              clean(log_id) unless skip_empty? && log_empty?(log_id)
            end
          end
          queue_archiving(log_id)
          Travis.logger.debug(
            'aggregating',
            action: 'aggregate', log_id: log_id, result: 'successful'
          )
        end

        attr_reader :database, :pool_config
        private :database
        private :pool_config

        private def aggregate(log_id)
          measure('aggregate') do
            database.aggregate(log_id)
          end
        end

        private def log_empty?(log_id)
          content = (database.log_for_id(log_id) || {})[:content]
          return false unless content.nil? || content.empty?

          Travis.logger.warn(
            'aggregating',
            action: 'aggregate', log_id: log_id, result: 'empty'
          )
          true
        end

        private def clean(log_id)
          measure('vacuum') do
            database.delete_log_parts(log_id)
          end
        end

        private def queue_archiving(log_id)
          return unless archive?

          log = database.log_for_id(log_id)
          if log
            Travis::Logs::Sidekiq::Archive.perform_async(log[:id])
          else
            mark('log.record_not_found')
            Travis.logger.warn(
              'aggregating',
              action: 'aggregate', log_id: log_id, result: 'not_found'
            )
          end
        end

        private def aggregatable_ids
          database.aggregatable_logs(
            intervals[:sweeper], intervals[:force],
            per_aggregate_limit,
            order: aggregatable_order
          )
        end

        private def intervals
          Travis.config.logs.intervals.to_h
        end

        private def per_aggregate_limit
          Travis.config.logs.per_aggregate_limit
        end

        private def archive?
          Travis.config.logs.archive?
        end

        private def skip_empty?
          Travis.config.logs.aggregate_clean_skip_empty
        end

        private def aggregatable_order
          value = Travis.config.logs.aggregatable_order.to_s.strip
          value.empty? ? nil : value
        end
      end
    end
  end
end
