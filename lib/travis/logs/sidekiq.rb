# frozen_string_literal: true

require 'uri'
require 'active_support/core_ext/hash/keys'
require 'sidekiq'
require 'travis/metrics/sidekiq'

module Travis
  module Logs
    module Sidekiq
      autoload :Aggregate, 'travis/logs/sidekiq/aggregate'
      autoload :Archive, 'travis/logs/sidekiq/archive'
      autoload :ErrorMiddleware, 'travis/logs/sidekiq/error_middleware'
      autoload :Honeycomb, 'travis/logs/sidekiq/honeycomb'
      autoload :LogParts, 'travis/logs/sidekiq/log_parts'
      autoload :PartmanMaintenance, 'travis/logs/sidekiq/partman_maintenance'
      autoload :Purge, 'travis/logs/sidekiq/purge'
      autoload :PusherForwarding, 'travis/logs/sidekiq/pusher_forwarding'
      autoload :TimingInfo, 'travis/logs/sidekiq/timing_info'

      class << self
        def setup
          Travis.logger.info(
            'setting up sidekiq and redis',
            pool_size: Travis.config.sidekiq.pool_size,
            host: URI(Travis.config.redis.url).host
          )
          ::Sidekiq.configure_server do |config|
            config.redis = {
              url: Travis.config.redis.url,
              ssl: config.redis.ssl || false,
              ssl_params: redis_ssl_params
            }
            config.logger = sidekiq_logger
            config.server_middleware do |chain|
              chain.add Travis::Logs::Sidekiq::ErrorMiddleware,
                        Travis.config.logs.sidekiq_error_retry_pause

              chain.add Metrics::Sidekiq
              chain.add Travis::Honeycomb::Sidekiq
            end
          end
        end

        def redis_ssl_params(config)
          @redis_ssl_params ||= begin
            return nil unless config.redis.ssl

            value = {}
            value[:ca_path] = ENV['REDIS_SSL_CA_PATH'] if ENV['REDIS_SSL_CA_PATH']
            value[:cert] = OpenSSL::X509::Certificate.new(File.read(ENV['REDIS_SSL_CERT_FILE'])) if ENV['REDIS_SSL_CERT_FILE']
            value[:key] = OpenSSL::PKEY::RSA.new(File.read(ENV['REDIS_SSL_KEY_FILE'])) if ENV['REDIS_SSL_KEY_FILE']
            value[:verify_mode] = OpenSSL::SSL::VERIFY_NONE if config.ssl_verify == false
            value
          end
        end

        private def sidekiq_logger
          return ::Logger.new($stdout) if Travis.config.log_level.to_s == 'debug'

          nil
        end
      end
    end
  end
end
