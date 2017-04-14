# frozen_string_literal: true

require 'uri'
require 'aws-sdk'

module Travis
  module Logs
    module Helpers
      class S3
        def self.setup
          Aws.config.update(
            region: 'us-east-1',
            credentials: Aws::Credentials.new(
              Travis::Logs.config.s3.access_key_id,
              Travis::Logs.config.s3.secret_access_key
            )
          )
        end

        attr_reader :s3

        def initialize
          @s3 = Aws::S3::Resource.new
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

        private def object(url)
          bucket(url).object(URI(url).path[1..-1])
        end

        private def bucket(url)
          s3.bucket(URI(url).host)
        end
      end
    end
  end
end
