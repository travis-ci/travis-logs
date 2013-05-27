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
          Travis::Memory.new(:logs).report_periodically if Travis.env == 'production'
        end

      end
    end
  end
end