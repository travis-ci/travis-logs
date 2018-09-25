# frozen_string_literal: true

require 'libhoney'
require 'thread'

module Travis
  class Honeycomb
    class << self
      def context
        Thread.current[:honeycomb_context] ||= Context.new
      end

      def enabled?
        ENV['HONEYCOMB_ENABLED'] == 'true'
      end

      def setup
        honey_setup
      end

      def override!
        context.override!
      end

      def clear
        context.clear
      end

      def honey
        @honey ||= Libhoney::Client.new(
          writekey:    ENV['HONEYCOMB_WRITEKEY'],
          dataset:     ENV['HONEYCOMB_DATASET'],
          sample_rate: ENV['HONEYCOMB_SAMPLE_RATE']&.to_i || 1,
        )
      end

      def honey_setup
        return unless enabled?

        # initialize shared client
        honey
      end

      def send(event)
        return unless enabled?

        ev = honey.event
        ev.add(event)

        if context.override
          ev.sample_rate = 1
          ev.send_presampled
        else
          ev.send
        end
      end
    end

    class Context
      class << self
        attr_accessor :permanent

        def add_permanent(field, value)
          @permanent ||= {}
          @permanent[field] = value
        end
      end

      attr_accessor :override

      def initialize
        @data = {}
        @override = false
      end

      def clear
        @data = {}
      end

      def add(field, value)
        @data[field] = value
      end

      def data
        (self.class.permanent || {}).merge(@data)
      end

      def override!
        @override = true
      end

      def clear
        @override = false
      end
    end
  end
end
