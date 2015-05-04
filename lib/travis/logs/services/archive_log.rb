require 'travis/logs/helpers/metrics'
require 'travis/logs/helpers/log_storage_provider'
require 'active_support/core_ext/object/try'
require 'active_support/core_ext/numeric/time'
require 'uri'

module Travis
  module Logs
    module Services
      class ArchiveLog
        include Helpers::Metrics

        METRIKS_PREFIX = "logs.archive"

        def self.metriks_prefix
          METRIKS_PREFIX
        end

        class VerificationFailed < StandardError
          def initialize(log_id, target_uri, expected, actual)
            super("Expected #{target_uri} (from log id: #{log_id}) to have the content length #{expected.inspect}, but had #{actual.inspect}")
          end
        end

        attr_reader :log_id


        def initialize(log_id, storage_service=nil, database=Travis::Logs.database_connection)
          @log_id = log_id
          @storage_service = storage_service || Travis::Logs::Helpers::LogStorageProvider.provider.new
          @database = database
        end

        def run
          return unless fetch
          mark_as_archiving
          return if content_blank?
          store
          verify
          confirm
          Travis.logger.debug "action=archive id=#{log_id} result=successful"
          queue_purge
        ensure
          mark_as_archiving(false)
        end

        def log
          @log ||= begin
            log = database.log_for_id(log_id)
            unless log
              Travis.logger.warn "action=archive id=#{log_id} result=not_found"
              mark('log.not_found')
            end
            log
          end
        end
        alias_method :fetch, :log

        def mark_as_archiving(archiving = true)
          database.update_archiving_status(log_id, archiving)
        end

        def content_blank?
          if content.blank?
            Travis.logger.warn "action=archive id=#{log_id} result=empty"
            mark("log.empty")
            true
          else
            false
          end
        end

        def store
          retrying(:store) do
            measure('store') do
              storage_service.store(content, log[:job_id])
            end
          end
        end

        def verify
          retrying(:verify) do
            measure('verify') do
              actual = archived_content_length
              expected = content.bytesize
              unless actual == expected
                raise VerificationFailed.new(log_id, target_uri, expected, actual)
              end
            end
          end
        end

        def confirm
          database.mark_archive_verified(log_id)
        end

        def queue_purge
          if Travis::Logs.config.logs.purge
            delay = Travis::Logs.config.logs.intervals.purge
            Sidekiq::Purge.perform_at(delay.hours.from_now, log_id)
          end
        end

        def target_uri
          storage_service.target_uri(log[:job_id])
        end

        private

          attr_reader :storage_service, :database

          def archived_content_length
            storage_service.content_length(log[:job_id])
          end

          def content
            @content ||= log[:content]
          end

          def content=(new_content)
            @content = new_content
          end

          def hostname
            Travis.config.s3.hostname
          end

          def retrying(header, times = 5)
            yield
          rescue => e
            count ||= 0
            if times > (count += 1)
              puts "[#{header}] retry #{count} because: #{e.message}"
              sleep count * 1
              retry
            else
              raise
            end
          end
      end
    end
  end
end
