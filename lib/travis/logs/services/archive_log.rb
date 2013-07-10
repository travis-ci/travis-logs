require 'travis/logs/helpers/metrics'
require 'travis/logs/helpers/s3'
require 'aws/s3'
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

        def initialize(log_id)
          @log_id = log_id
        end

        def run
          return unless fetch
          mark_as_archiving
          store
          verify
          confirm
        ensure
          mark_as_archiving(false)
        end

        def log
          @log ||= begin
            log = connection[:logs].where(id: log_id).first
            unless log
              Travis.logger.warn "[warn] log with id:#{payload['id']} could not be found"
              mark('log.not_found')
            end
            log
          end
        end
        alias_method :fetch, :log

        def mark_as_archiving(archiving = true)
          connection[:logs].where(id: log_id).update(archiving: archiving)
        end

        def store
          retrying(:store) do
            measure('store') do
              s3.store(content)
            end
          end
        end

        def verify
          retrying(:verify) do
            measure('verify') do
              unless content.bytesize == archived_content_length
                raise VerificationFailed.new(log_id, target_url, expected, actual)
              end
            end
          end
        end

        def confirm
          connection[:logs].where(id: log_id).update(archived_at: Time.now, archive_verified: true)
        end

        def target_url
          "http://#{hostname('archive')}/jobs/#{log[:job_id]}/log.txt"
        end

        private

          def archived_content_length
            http.head(target_url).headers['content-length'].try(:to_i)
          end

          def content
            log[:content]
          end

          def connection
            Travis::Logs.database_connection
          end

          def http
            Faraday.new(ssl: Travis.config.ssl.compact) do |f|
              f.request :url_encoded
              f.adapter :net_http
            end
          end

          def s3
            @s3 ||= Helpers::S3.new(target_url)
          end

          def hostname(name)
            "#{name}#{'-staging' if Travis.env == 'staging'}.#{Travis.config.host.split('.')[-2, 2].join('.')}"
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
