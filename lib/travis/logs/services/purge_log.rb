require "travis/logs/helpers/metrics"
require "travis/logs/helpers/s3"
require "travis/logs/sidekiq"
require "travis/logs/sidekiq/archive"

module Travis
  module Logs
    module Services
      class PurgeLog
        include Helpers::Metrics

        METRIKS_PREFIX = "logs.purge"

        def self.metriks_prefix
          METRIKS_PREFIX
        end

        def initialize(log_id, storage_service = nil, database = nil, archiver = nil)
          @log_id = log_id
          @storage_service = storage_service || Helpers::S3.new
          @database = database || Travis::Logs.database_connection
          @archiver = archiver || ->(log_id) { Sidekiq::Archive.perform_async(log_id) }
        end

        def run
          if content.nil?
            process_empty_log_content
          else
            process_log_content
          end
        end

        private

        def process_empty_log_content
          if content_length.nil?
            Travis.logger.warn("[warn] log with id:#{@log_id} missing in database or on S3")
            mark('log.content_empty')
          else
            measure('already_purged') do
              @database.transaction do
                @database.mark_archive_verified(@log_id)
                @database.purge(@log_id)
              end
            end
            Travis.logger.info "log with id:#{@log_id} was already archived, has now been purged"
          end
        end

        def process_log_content
          if content_length == content.length
            measure('purged') do
              @database.purge(@log_id)
            end
            Travis.logger.info "log with id:#{@log_id} purged from db (db and s3 content lengths match content_length:#{content_length})"
          else
            measure('requeued_for_achiving') do
              @database.mark_not_archived(@log_id)
              @archiver.call(@log_id)
            end
            Travis.logger.info "log with id:#{@log_id} queued to be reachived as db and s3 content lengths don't match (db:#{content.length} s3:#{content_length})"
          end
        end

        def content
          log[:content]
        end

        def content_length
          @content_length ||= begin
            begin
              measure('check_content_length') do
                @storage_service.content_length(log_url)
              end
            rescue => e
              mark('check_content_length.failed')
            end
          end
        end

        def log
          unless defined?(@log)
            @log = @database.log_for_id(@log_id)
            unless @log
              Travis.logger.warn("[warn] log with id:#{@log_id} could not be found")
              mark("log.not_found")
            end
          end

          @log
        end

        def log_url
          "http://#{Travis.config.s3.hostname}/jobs/#{log[:job_id]}/log.txt"
        end
      end
    end
  end
end
