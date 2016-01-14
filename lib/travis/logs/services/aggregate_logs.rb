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

        def self.aggregate_log(log_id)
          new.aggregate_log(log_id)
        end

        def initialize(database = nil)
          @database = database || Travis::Logs.database_connection
        end

        def run
          ids = aggregateable_ids

          if aggregate_async?
            Travis.logger.info "action=aggregate async=true n=#{ids.length}"

            ids.each do |log_id|
              Travis::Logs::Sidekiq::Aggregate.perform_async(log_id)
            end

            return
          end

          Travis.logger.info "action=aggregate async=false n=#{ids.length}"
          ids.each { |log_id| aggregate_log(log_id) }
        end

        def aggregate_log(log_id)
          transaction do
            aggregate(log_id)
            vacuum(log_id) unless log_empty?(log_id)
          end
          queue_archiving(log_id)
          Travis.logger.debug "action=aggregate log_id=#{log_id} result=successful"
        rescue => e
          Travis::Exceptions.handle(e)
        end

        private

        attr_reader :database

        def aggregate(log_id)
          measure('aggregate') do
            database.aggregate(log_id)
          end
        end

        def log_empty?(log_id)
          log = database.log_for_id(log_id)
          if log[:content].nil? || log[:content].empty?
            Travis.logger.warn "action=aggregate log_id=#{log_id} result=empty"
            true
          end
        end

        def vacuum(log_id)
          measure('vacuum') do
            database.delete_log_parts(log_id)
          end
        end

        def queue_archiving(log_id)
          return unless archive?

          log = database.log_for_id(log_id)

          if log
            Travis::Logs::Sidekiq::Archive.perform_async(log[:id])
          else
            mark('log.record_not_found')
            Travis.logger.warn "action=aggregate log_id=#{log_id} result=not_found"
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
