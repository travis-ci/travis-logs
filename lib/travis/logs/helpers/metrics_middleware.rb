require 'travis/logs/helpers/metrics'

module Travis
  module Logs
    module Helpers
      class MetricsMiddleware
        include Travis::Logs::Helpers::Metrics

        METRIKS_PREFIX = 'logs.app'.freeze

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
          [
            (env['REQUEST_METHOD'] || 'unk').downcase,
            (
              env['PATH_INFO'].to_s
            ).sub('/', '').gsub(/[[:digit:]]+/, 'id')
          ].join('.').gsub(/[^\.[:alnum:]]+/, '_')
        end
      end
    end
  end
end
