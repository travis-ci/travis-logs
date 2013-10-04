require 'travis/logs/helpers/metrics'
require 'travis/logs/helpers/s3'
require 'active_support/core_ext/object/try'
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
          def initialize(log_id, target_url, expected, actual)
            super("Expected #{target_url} (from log id: #{log_id}) to have the content length #{expected.inspect}, but had #{actual.inspect}")
          end
        end

        attr_reader :log_id

        def initialize(log_id, storage_service=Helpers::S3.new, database=Travis::Logs.database_connection)
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
        ensure
          mark_as_archiving(false)
        end

        def log
          @log ||= begin
            log = database.log_for_id(log_id)
            unless log
              Travis.logger.warn "[warn] log with id:#{log_id} could not be found"
              mark('log.not_found')
            end
            log
          end
        end
        alias_method :fetch, :log

        def mark_as_archiving(archiving = true)
          database.mark_as_archiving(log_id, archiving)
        end

        def content_blank?
          if content.blank?
            Travis.logger.warn "[warn] log with id:#{log_id} was blank"
            mark("log.empty")
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
                raise VerificationFailed.new(log_id, target_url, expected, actual)
              end
            end
          end
        end

        def confirm
          database.mark_archive_verified(log_id)
        end

        def target_url
          "http://#{hostname}/jobs/#{log[:job_id]}/log.txt"
        end

        private

          attr_reader :storage_service, :database

          def archived_content_length
            storage_service.content_length(target_url)
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
