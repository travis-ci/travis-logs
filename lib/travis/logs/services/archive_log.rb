# frozen_string_literal: true

require 'uri'

require 'active_support/core_ext/object/try'
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
          return unless fetch

          mark_as_archiving
          return if content_blank?

          store
          verify
          confirm
          Travis.logger.debug(
            'archived log',
            action: 'archive', id: log_id, job_id: job_id, result: 'successful'
          )
          queue_purge
          queue_timing_info(log_id)
        ensure
          mark_as_archiving(false)
        end

        def log
          @log ||= begin
            log = database.log_for_id(log_id)
            unless log
              Travis.logger.warn(
                'log not found',
                action: 'archive', id: log_id, result: 'not_found'
              )
              mark('log.not_found')
            end
            log
          end
        end
        alias fetch log

        def mark_as_archiving(archiving = true)
          database.update_archiving_status(log_id, archiving)
        end

        def content_blank?
          if content.blank?
            Travis.logger.warn(
              'content empty',
              action: 'archive', id: log_id, result: 'empty'
            )
            mark('log.empty')
            true
          else
            false
          end
        end

        def store
          retrying(:store) do
            measure('store') do
              storage_service.store(content, target_url)
            end
          end
        end

        def verify
          retrying(:verify) do
            measure('verify') do
              actual = archived_content_length
              expected = content.bytesize
              unless actual == expected
                Travis.logger.error(
                  'error while verifying',
                  action: 'archive', id: log_id, result: 'verification-failed',
                  expected: expected, actual: actual
                )
                raise VerificationFailed.new(
                  log_id, target_url, expected, actual
                )
              end
            end
          end
        end

        def confirm
          database.mark_archive_verified(log_id)
        end

        def queue_purge
          return unless Travis::Logs.config.logs.purge?

          delay = Travis::Logs.config.logs.intervals.purge
          Travis::Logs::Sidekiq::Purge.perform_at(delay.hours.from_now, log_id)
        end

        def target_url
          "http://#{hostname}/jobs/#{job_id}/log.txt"
        end

        attr_reader :storage_service, :database
        private :storage_service
        private :database

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

        private def hostname
          Travis.config.s3.hostname
        end

        private def queue_timing_info(log_id)
          Travis::Logs::Sidekiq::TimingInfo.perform_async(database.job_id_for_log_id(log_id))
        end

        private def retrying(header, times: retry_times)
          yield
        rescue StandardError => e
          count ||= 0
          count += 1
          if times > count
            Travis.logger.debug(
              'error while archiving',
              action: 'archive', retrying: header,
              error: MultiJson.dump(e.backtrace), type: e.class.name
            )
            Travis.logger.warn(
              'error while archiving',
              action: 'archive', retrying: header,
              reason: e.message, id: log_id, job_id: job_id
            )
            sleep count * 1
            retry
          else
            Travis.logger.error(
              'error while archiving',
              action: 'archive', retrying: header, exceeded: times,
              error: e.backtrace.first, type: e.class.name
            )
            raise
          end
        end

        private def retry_times
          @retry_times ||= 5
        end
      end
    end
  end
end
