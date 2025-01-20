# frozen_string_literal: true

require 'travis/lock'

module Travis
  module Logs
    class Lock
      def initialize(key, options: nil)
        @key = key
        @lock_options = normalized_locking_options(options: options)
      end

      attr_reader :key, :lock_options
      private :key
      private :lock_options

      def exclusive(&block)
        Travis.logger.debug('locking', lock_options.merge(key: key))
        Travis::Lock.exclusive(key, lock_options, &block)
      end

      private def normalized_locking_options(options: nil)
        options ||= base_lock_config
        if options[:strategy] == :redis
          options[:url] ||= redis_url
          options[:ssl] ||= Travis.config.redis.ssl || false
          options[:ca_path] ||= ENV['REDIS_SSL_CA_PATH'] if ENV['REDIS_SSL_CA_PATH']
          options[:cert] ||= OpenSSL::X509::Certificate.new(File.read(ENV['REDIS_SSL_CERT_FILE'])) if ENV['REDIS_SSL_CERT_FILE']
          options[:key] ||= OpenSSL::PKEY::RSA.new(File.read(ENV['REDIS_SSL_KEY_FILE'])) if ENV['REDIS_SSL_KEY_FILE']
          options[:verify_mode] ||= OpenSSL::SSL::VERIFY_NONE if Travis.config.ssl_verify == false
        end
        options
      end

      private def redis_url
        Travis.config.redis.url
      end

      private def base_lock_config
        Travis.config.lock.to_h
      end
    end
  end
end
