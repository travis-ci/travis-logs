# frozen_string_literal: true

require 'travis/logs'

module Travis
  module Logs
    module Services
      class PurgeLog
        include Travis::Logs::MetricsMethods

        METRIKS_PREFIX = 'logs.purge'

        def self.metriks_prefix
          METRIKS_PREFIX
        end

        def initialize(log_id, storage_service = nil, database = nil,
                       archiver = nil)
          @log_id = log_id
          @storage_service = storage_service || Travis::Logs::S3.new
          @database = database || Travis::Logs.database_connection
          @archiver = archiver || proc do
            Travis::Logs::Sidekiq::Archive.perform_async(log_id)
          end
        end

        attr_reader :archiver, :database, :storage_service
        private :archiver
        private :database
        private :storage_service

        def run
          if db_content_length_empty?
            process_empty_log_content
          else
            process_log_content
          end
        end

        private def db_content_length_empty?
          content_length_from_db.nil? || content_length_from_db.zero?
        end

        private def process_empty_log_content
          if content_length_from_s3.nil?
            Travis.logger.warn(
              'no content',
              action: 'purge', id: @log_id, result: 'content_missing'
            )
            mark('log.content_empty')
          else
            measure('already_purged') do
              database.db.transaction do
                database.mark_archive_verified(@log_id)
                database.purge(@log_id)
              end
            end
            Travis.logger.info(
              'no content',
              action: 'purge', id: @log_id, result: 'already_archived'
            )
          end
        end

        private def process_log_content
          if content_lengths_match?
            measure('purged') do
              database.purge(@log_id)
            end
            Travis.logger.debug(
              'content lengths match',
              action: 'purge', id: @log_id,
              result: 'successful', content_length: content_length_from_db
            )
          else
            measure('requeued_for_achiving') do
              database.mark_not_archived(@log_id)
              archiver.call(@log_id)
            end
            Travis.logger.info(
              'content lengths do not match',
              action: 'purge', id: @log_id, result: 'requeued',
              db_content_length: content_length_from_db,
              s3_content_length: content_length_from_s3
            )
          end
        end

        private def content_lengths_match?
          content_length_from_db == content_length_from_s3
        end

        private def content_length_from_db
          log[:content_length]
        end

        private def content_length_from_s3
          @content_length_from_s3 ||= begin
            measure('check_content_length') do
              storage_service.content_length(log_url)
            end
          rescue StandardError
            mark('check_content_length.failed')
          end
        end

        private def log
          unless defined?(@log)
            @log = database.log_content_length_for_id(@log_id)
            unless @log
              Travis.logger.warn(
                'log not found',
                action: 'purge', id: @log_id, result: 'not_found'
              )
              mark('log.not_found')
            end
          end
          @log
        end

        private def log_url
          "http://#{Travis.config.s3.hostname}/jobs/#{log[:job_id]}/log.txt"
        end
      end
    end
  end
end
