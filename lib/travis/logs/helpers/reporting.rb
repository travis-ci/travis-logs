require 'metriks'
require 'metriks/reporter/logger'
require 'travis/support/log_subscriber/active_record_metrics'
require 'travis/support/memory'

module Travis
  module Logs
    module Helpers
      module Reporting

        def self.setup
          Travis.logger.info('Setting up Metriks')
          if Travis.config.librato
            email, token, source = Travis.config.librato.email, Travis.config.librato.token, Travis.config.librato_source
            reporter = Metriks::LibratoMetricsReporter.new(email, token, source: source)
            reporter.start
          end
        end

      end
    end
  end
end