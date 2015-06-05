require 'aws/s3'

module Travis
  module Logs
    module Helpers
      class S3
        class << self
          def setup
            AWS.config(Travis::Logs.config.s3.to_hash.slice(:access_key_id, :secret_access_key))
          end
        end

        attr_reader :s3

        def initialize
          @s3 = AWS::S3.new
        end

        def store(data, log_id)
          object(target_uri(log_id)).write(data, content_type: 'text/plain', acl: Travis::Logs.config.s3.acl)
        end

        def content_length(log_id)
          object(target_uri(log_id)).content_length
        end

        def target_uri(log_id)
          hostname = Travis::Logs.config.s3.hostname;
          "http://#{hostname}/jobs/#{log_id}/log.txt"
        end

      private

        def object(log_id)
          bucket(log_id).objects[URI.parse(log_id).path[1..-1]]
        end

        def bucket(log_id)
          s3.buckets[URI.parse(log_id).host]
        end
      end
    end
  end
end
