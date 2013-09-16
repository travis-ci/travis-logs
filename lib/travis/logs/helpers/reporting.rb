require 'metriks'
require 'metriks/reporter/logger'
require 'travis/support/log_subscriber/active_record_metrics'
require 'travis/support/memory'

module Travis
  module Logs
    module Helpers
      module Reporting

        def self.setup
          Travis.logger.info('Setting up Metriks and Memory reporting')
          Metriks::Reporter::Logger.new.start
          Travis::LogSubscriber::ActiveRecordMetrics.attach
        end

      end
    end
  end
end