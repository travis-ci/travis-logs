# frozen_string_literal: true

require 'metriks'

module Travis
  module Logs
    module MetricsMethods
      def measure(name = nil, &block)
        timer_name = [self.class.metriks_prefix, name].compact.join('.')
        Metriks.timer(timer_name).time(&block)
      rescue StandardError
        failed_name = [name, 'failed'].compact.join('.')
        mark(failed_name)
        raise
      end

      def mark(name)
        Metriks.meter("#{self.class.metriks_prefix}.#{name}").mark
      end
    end
  end
end
