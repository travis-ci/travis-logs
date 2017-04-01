# frozen_string_literal: true

module Travis
  module Logs
    module Helpers
      module Metrics
        def measure(name = nil, &block)
          timer_name = [self.class.metriks_prefix, name].compact.join('.')
          Metriks.timer(timer_name).time(&block)
        rescue
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
end
