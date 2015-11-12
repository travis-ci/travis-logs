require 'aws/s3'

module Travis
  module Logs
    module Helpers
      class S3
        class << self
          def setup
            AWS.config(Travis::Logs.config.s3.to_hash.slice(:access_key_id, :secret_access_key))
            :alldone
          end
        end

        attr_reader :s3, :url

        def initialize
          @s3 = AWS::S3.new
        end

        def store(data, url)
          object(url).write(data, content_type: 'text/plain', acl: Travis::Logs.config.s3.acl)
        end

        def content_length(url)
          object(url).content_length
        end

        private

        def object(url)
          bucket(url).objects[URI.parse(url).path[1..-1]]
        end

        def bucket(url)
          s3.buckets[URI.parse(url).host]
        end
      end
    end
  end
end
