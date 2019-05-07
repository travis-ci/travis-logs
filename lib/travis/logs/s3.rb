# frozen_string_literal: true

require 'uri'
require 'aws-sdk'

require 'travis/logs'

module Travis
  module Logs
    class S3
      def self.setup
        self.org_credentials = self.setup_credentials(:org)
        self.com_credentials = self.setup_credentials(:com)
      end

      def self.setup_credentials(:org)
        Aws::Credentials.new(
          Travis.config.s3.org_access_key_id,
          Travis.config.s3.org_secret_access_key
        )
      end

      def self.setup_credentials(:com)
        Aws::Credentials.new(
          Travis.config.s3.com_access_key_id,
          Travis.config.s3.com_secret_access_key
        )
      end

      attr_reader :org_s3, :com_s3

      def initialize
        @org_s3 = Aws::S3::Resource.new(region: 'us-east-1', credentials: self.org_credentials)
        @com_s3 = Aws::S3::Resource.new(region: 'us-east-1', credentials: self.com_credentials)
      end

      def store(data, url)
        object(URI(url)).put(
          body: data,
          content_type: 'text/plain',
          acl: acl
        )
      end

      def content_length(url)
        object(URI(url)).content_length
      end

      private def object(uri)
        bucket(uri).object(uri.path[1..-1])
      end

      private def bucket(uri)
        s3_resource.bucket(uri.host)
      end

      private def s3_resource
        # logic to decide which s3 bucket we use here.
        # Something like this:
        # If we are deployed on com, and if a log's repo has been migrated
        # and the job has not been restarted, use org. Otherwise, use com.
        # If we are deployed on org, use org.
      end

      private def acl
        @acl ||= Travis.config.s3.acl.to_s.tr('_', '-')
      end
    end
  end
end
