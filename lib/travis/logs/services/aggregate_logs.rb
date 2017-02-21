require 'concurrent'

require 'travis/logs/helpers/metrics'
require 'travis/logs/sidekiq/archive'

module Travis
  module Logs
    module Services
      class AggregateLogs
        include Helpers::Metrics

        METRIKS_PREFIX = 'logs.aggregate_logs'.freeze

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
                           Travis::Logs.config.logs.aggregate_pool.to_h
                         else
                           pool_config
                         end
        end

        def run
          Travis.logger.info('fetching aggregatable ids')

          ids = aggregatable_ids
          if ids.empty?
            Travis.logger.info('no aggregatable ids')
            return
          end

          Travis.logger.debug(
            'aggregating with pool config',
            pool_config.merge(action: 'aggregate')
          )
          Travis.logger.info(
            'starting aggregation batch',
            action: 'aggregate', :'sample#aggregatable-logs' => ids.length
          )

          pool = Concurrent::ThreadPoolExecutor.new(pool_config)
          ids.each { |i| pool.post { aggregate_log(i) } }
          pool.shutdown
          pool.wait_for_termination

          Travis.logger.info('finished aggregation batch', action: 'aggregate')
        end

        def run_ranges(cursor, per_page)
          cursor ||= database.min_log_part_id

          Travis.logger.info('fetching aggregatable ids', cursor: cursor)
          ids = database.aggregatable_log_parts_page(cursor, per_page)

          if ids.empty?
            # Travis.logger.info('no aggregatable ids')
            return cursor + per_page
          end

          Travis.logger.debug(
            'aggregating with pool config',
            pool_config.merge(action: 'aggregate')
          )
          Travis.logger.info(
            'starting aggregation batch',
            action: 'aggregate', :'sample#aggregatable-logs' => ids.length
          )

          pool = Concurrent::ThreadPoolExecutor.new(pool_config)
          ids.each { |i| pool.post { aggregate_log(i) } }
          pool.shutdown
          pool.wait_for_termination

          Travis.logger.info('finished aggregation batch', action: 'aggregate')
          cursor + per_page
        end

        def aggregate_log(log_id)
          measure do
            database.transaction do
              aggregate(log_id)
              vacuum(log_id) unless skip_empty? && log_empty?(log_id)
            end
          end
          queue_archiving(log_id)
          Travis.logger.debug(
            'aggregating',
            action: 'aggregate', log_id: log_id, result: 'successful'
          )
        rescue => e
          Travis::Exceptions.handle(e)
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
          log = database.log_for_id(log_id)
          if log[:content].nil? || log[:content].empty?
            Travis.logger.warn(
              'aggregating',
              action: 'aggregate', log_id: log_id, result: 'empty'
            )
            true
          end
        end

        private def vacuum(log_id)
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
          database.aggregatable_log_parts(
            intervals[:regular], intervals[:force], per_aggregate_limit
          ).uniq
        end

        private def intervals
          Travis.config.logs.intervals
        end

        private def per_aggregate_limit
          Travis.config.logs.per_aggregate_limit
        end

        private def archive?
          Travis.config.logs.archive
        end

        private def skip_empty?
          Travis.config.logs.vacuum_skip_empty
        end
      end
    end
  end
end
