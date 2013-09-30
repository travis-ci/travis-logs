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

        attr_reader :s3, :url

        def initialize(url)
          @s3 = AWS::S3.new
          @url = url
        end

        def store(data)
          object.write(data, content_type: 'text/plain', acl: Travis::Logs.config.s3.acl)
        end

        def object
          @object ||= bucket.objects[URI.parse(url).path[1..-1]]
        end

        def bucket
          @bucket ||= s3.buckets[URI.parse(url).host]
        end
      end
    end
  end
end