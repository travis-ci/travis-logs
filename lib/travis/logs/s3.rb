# frozen_string_literal: true

require 'uri'
require 'aws-sdk'

require 'travis/logs'

module Travis
  module Logs
    class S3
      def self.setup
        return unless Travis.config.s3

        Aws.config.update(
          region: ENV['TRAVIS_LOGS_S3_REGION'] || Travis.config.log_options&.s3&.region || 'us-east-2',
          credentials: Aws::Credentials.new(
            Travis.config.s3.access_key_id,
            Travis.config.s3.secret_access_key
          ),
          endpoint: endpoint
        )
      end

      attr_reader :s3

      def initialize
        @s3 = Aws::S3::Resource.new
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

      def self.endpoint
        return unless Travis.config.s3

        Travis.config.s3.endpoint&.index('http')&.zero? ? Travis.config.s3.endpoint : "https://#{Travis.config.s3.endpoint}"
      end

      private def bucket(uri)
        Travis.logger.warn(
          'final url',
          uri: uri
        )
        Travis.logger.warn(
          'uri host',
          host: uri.host
        )

        s3.bucket(uri.host)
      end

      private def acl
        @acl ||= Travis.config.s3.acl.to_s.tr('_', '-')
      end
    end
  end
end
