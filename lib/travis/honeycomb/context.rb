# frozen_string_literal: true

module Travis
  module Honeycomb
    class Context
      class << self
        attr_accessor :global_tags

        def tag(key, value)
          @global_tags ||= {}
          @global_tags[key] = value
        end
      end

      attr_accessor :sample_rate

      def initialize
        @tags = {}
        @data = {}
        @always_sample = false
        @sample_rate = nil
      end

      def clear
        @tags = {}
        @data = {}
        @always_sample = false
        @sample_rate = nil
      end

      def tag(key, value)
        @tags[key] = value
      end

      def tags(h)
        @tags.merge!(h)
      end

      def set(key, value)
        @data[key] = value
      end

      def merge(h)
        @data.merge!(h)
      end

      def increment(key, value = 1)
        @data[key] ||= 0
        @data[key] += value
      end

      def data
        (self.class.global_tags || {}).merge(@tags).merge(@data)
      end

      def always_sample?
        @always_sample
      end

      def always_sample!
        @always_sample = true
      end
    end
  end
end
