module Travis
  module Logs
    module Services
      class FetchLog
        class Result
          def initialize(content: '', archive_url: '', archived: false)
            @content = content
            @archive_url = archive_url
            @archived = archived
          end

          attr_reader :content, :archive_url

          def archived?
            !@archived.nil?
          end
        end

        def initialize(database: nil)
          @database = database || Travis::Logs.database_connection
        end

        attr_reader :database
        private :database

        def run(job_id: nil)
          return nil if job_id.nil?

          log = database.log_for_job_id(job_id)
          return nil if log.nil?

          archive_url = ''
          archive_url = build_archive_url(job_id) unless log[:archived_at].nil?

          content = log[:content]
          if log[:aggregated_at].nil?
            content = [
              content, database.aggregated_on_demand(log[:id])
            ].join('')
          end

          Result.new(
            content: content,
            archive_url: archive_url,
            archived: log[:archived_at]
          )
        end

        private def build_archive_url(job_id)
          [
            'http://s3.amazonaws.com', s3_bucket,
            'jobs', job_id.to_s, 'log.txt'
          ].join('/')
        end

        private def s3_bucket
          Travis::Logs.config.s3.hostname
        end
      end
    end
  end
end
