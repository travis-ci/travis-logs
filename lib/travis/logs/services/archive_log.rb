# frozen_string_literal: true

require 'active_support/core_ext/numeric/time'
require 'multi_json'

module Travis
  module Logs
    module Services
      class ArchiveLog
        include Travis::Logs::MetricsMethods

        METRIKS_PREFIX = 'logs.archive'

        def self.metriks_prefix
          METRIKS_PREFIX
        end

        class VerificationFailed < StandardError
          def initialize(log_id, target_url, expected, actual)
            super(
              "Expected #{target_url} (from log id: #{log_id}) " \
              "to have the content length #{expected.inspect}, but " \
              "had #{actual.inspect}"
            )
          end
        end

        attr_reader :log_id

        def initialize(
          log_id,
          storage_service: Travis::Logs::S3.new,
          database: Travis::Logs.database_connection
        )
          @log_id = log_id
          @storage_service = storage_service
          @database = database
        end

        def run
          if log.nil?
            Travis.logger.warn(
              'log not found',
              action: 'archive', id: log_id, result: 'not_found'
            )
            mark('log.not_found')
            return
          end

          if content.blank?
            Travis.logger.warn(
              'content empty',
              action: 'archive', id: log_id, job_id: job_id, result: 'empty'
            )
            mark('log.empty')
            return
          end

          archive
        end

        attr_reader :storage_service, :database
        private :storage_service
        private :database

        private def archive
          database.update_archiving_status(log_id, true)

          measure('store') { store }
          measure('verify') { verify }

          database.mark_archive_verified(log_id)

          queue_purge if purge?

          Travis.logger.debug(
            'archived log',
            action: 'archive', id: log_id, job_id: job_id, result: 'successful'
          )
        ensure
          database.update_archiving_status(log_id, false)
        end

        private def queue_purge
          Travis::Logs::Sidekiq::Purge.perform_at(purge_at, log_id)
        end

        private def target_url
          "http://#{hostname}/jobs/#{job_id}/log.txt"
        end

        private def log
          @log ||= database.log_for_id(log_id)
        end

        private def store
          storage_service.store(content, target_url)
        end

        private def verify
          actual = archived_content_length
          expected = content.bytesize
          return if actual == expected

          Travis.logger.error(
            'error while verifying',
            action: 'archive', id: log_id, result: 'verification-failed',
            expected: expected, actual: actual
          )
          raise VerificationFailed.new(
            log_id, target_url, expected, actual
          )
        end

        private def archived_content_length
          storage_service.content_length(target_url)
        end

        private def content
          @content ||= log[:content]
        end

        private def job_id
          (log || {}).fetch(:job_id, 'unknown')
        end

        attr_writer :content
        private :content

        private def config
          Travis::Logs.config.to_h
        end

        private def hostname
          config[:s3][:hostname]
        end

        private def purge?
          config[:logs][:purge]
        end

        private def purge_at
          config[:logs][:intervals][:purge].hours.from_now
        end
      end
    end
  end
end
