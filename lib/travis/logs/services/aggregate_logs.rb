require 'travis/logs/helpers/metrics'
require 'travis/logs/sidekiq/archive'
require 'travis/logs/sidekiq/aggregate'

module Travis
  module Logs
    module Services
      class AggregateLogs
        include Helpers::Metrics

        METRIKS_PREFIX = "logs.aggregate_logs"

        def self.metriks_prefix
          METRIKS_PREFIX
        end

        def self.run
          new.run
        end

        def self.aggregate_ids(log_part_ids)
          new.aggregate_ids(log_part_ids)
        end

        def initialize(database = nil)
          @database = database || Travis::Logs.database_connection
        end

        def run
          ids = aggregateable_ids

          if aggregate_async?
            Travis.logger.info "action=aggregate async=true n=#{ids.length}"
            Travis::Logs::Sidekiq::Aggregate.perform_async(ids)
            return
          end

          Travis.logger.info "action=aggregate async=false n=#{ids.length}"
          aggregate_ids(ids)
        end

        def aggregate_ids(log_part_ids)
          log_part_ids.each do |id|
            aggregate_log(id)
          end
        end

        private

        attr_reader :database

        def aggregate_log(id)
          transaction do
            aggregate(id)
            unless log_empty?(id)
              vacuum(id)
            end
          end
          queue_archiving(id)
          Travis.logger.debug "action=aggregate id=#{id} result=successful"
        rescue => e
          Travis::Exceptions.handle(e)
        end

        def aggregate(id)
          measure('aggregate') do
            database.aggregate(id)
          end
        end

        def log_empty?(id)
          log = database.log_for_id(id)
          if log[:content].nil? || log[:content].empty?
            warn "action=aggregate id=#{id} result=empty"
            true
          end
        end

        def vacuum(id)
          measure('vacuum') do
            database.delete_log_parts(id)
          end
        end

        def queue_archiving(id)
          return unless archive?

          log = database.log_for_id(id)

          if log
            Travis::Logs::Sidekiq::Archive.perform_async(log[:id])
          else
            mark('log.record_not_found')
            Travis.logger.warn "action=aggregate id=#{id} result=not_found"
          end
        end

        def aggregateable_ids
          database.aggregatable_log_parts(
            intervals[:regular], intervals[:force], per_aggregate_limit
          ).uniq
        end

        def intervals
          Travis.config.logs.intervals
        end

        def per_aggregate_limit
          Travis.config.logs.per_aggregate_limit
        end

        def archive?
          Travis.config.logs.archive
        end

        def aggregate_async?
          Travis.config.logs.aggregate_async
        end

        def transaction(&block)
          measure do
            database.transaction(&block)
          end
        end
      end
    end
  end
end
