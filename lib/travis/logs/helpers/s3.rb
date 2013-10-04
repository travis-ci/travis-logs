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

        def initialize
          @s3 = AWS::S3.new
          @objects = {}
          @buckets = {}
        end

        def store(data, url)
          object(url).write(data, content_type: 'text/plain', acl: Travis::Logs.config.s3.acl)
        end

        def content_length(url)
          http.head(url).headers["content-length"].try(:to_i)
        end

        private

        def object(url)
          @objects.fetch(url) { bucket(url).objects[URI.parse(url).path[1..-1]] }
        end

        def bucket(url)
          @buckets.fetch(url) { s3.buckets[URI.parse(url).host] }
        end

        def http
          Faraday.new(ssl: Travis.config.ssl.compact) do |f|
            f.request :url_encoded
            f.adapter :net_http
          end
        end
      end
    end
  end
end
