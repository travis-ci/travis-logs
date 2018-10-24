# frozen_string_literal: true

require 'uri'
require 'aws-sdk'

require 'travis/logs'

module Travis
  module Logs
    class S3
      def self.setup
        Aws.config.update(
          region: Travis.config.s3.region || 'us-east-1',
          endpoint: Travis.config.s3.endpoint,
          force_path_style: Travis.config.s3.force_path_style,
          credentials: Aws::Credentials.new(
            Travis.config.s3.access_key_id,
            Travis.config.s3.secret_access_key
          )
        )
      end

      attr_reader :s3

      def initialize
        @s3 = Aws::S3::Resource.new
      end

      def store(data, path)
        object(path).put(
          body: data,
          content_type: 'text/plain',
          acl: acl
        )
      end

      def content_length(path)
        object(path).content_length
      end

      private def object(path)
        bucket.object(path)
      end

      private def bucket
        s3.bucket(bucket_name)
      end

      private def bucket_name
        @bucket_name ||= Travis.config.s3.bucket_name
      end

      private def acl
        @acl ||= Travis.config.s3.acl.to_s.tr('_', '-')
      end
    end
  end
end
