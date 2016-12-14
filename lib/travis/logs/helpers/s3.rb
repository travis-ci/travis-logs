require 'aws-sdk'

module Travis
  module Logs
    module Helpers
      class S3
        attr_reader :s3

        def initialize
          @s3 = Aws::S3::Resource.new(
            access_key_id: Travis::Logs.config.s3.access_key_id,
            secret_access_key: Travis::Logs.config.s3.secret_access_key,
            region: 'us-east-1'
          )
        end

        def store(data, url)
          object(url).put(
            body: data,
            content_type: 'text/plain',
            acl: Travis::Logs.config.s3.acl.to_s.tr('_', '-')
          )
        end

        def content_length(url)
          object(url).content_length
        end

        private

        def object(url)
          bucket(url).object(URI.parse(url).path[1..-1])
        end

        def bucket(url)
          s3.bucket(URI.parse(url).host)
        end
      end
    end
  end
end
