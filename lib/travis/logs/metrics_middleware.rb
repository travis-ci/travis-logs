# frozen_string_literal: true

require 'travis/logs'

module Travis
  module Logs
    class MetricsMiddleware
      include Travis::Logs::MetricsMethods

      METRIKS_PREFIX = 'logs.app'
      KNOWN_TIMER_NAMES = %w[
        get.logs_id
        get.logs_id_id
        get.uptime
        post.logs_multi
        post.pusher_existence
        put.log_parts_id_id
        put.logs_id
        put.logs_id_archived
      ].freeze

      def self.metriks_prefix
        METRIKS_PREFIX
      end

      def initialize(app)
        @app = app
      end

      def call(env)
        measure(timer_name(env)) do
          @app.call(env)
        end
      end

      private def timer_name(env)
        name = [
          (env['REQUEST_METHOD'] || 'unk').downcase,
          env['PATH_INFO'].to_s
            .sub('/', '')
            .gsub(/[[:digit:]]+/, 'id')
                          .gsub(/\.+/, '.')
        ].join('.')
               .gsub(/[^\.[:alnum:]]+/, '_')
               .gsub(/[\._]+$/, '')
        return name if KNOWN_TIMER_NAMES.include?(name)

        'unk.unk'
      end
    end
  end
end
