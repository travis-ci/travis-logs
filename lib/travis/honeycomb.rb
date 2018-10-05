# frozen_string_literal: true

require 'libhoney'
require 'thread'

require 'travis/honeycomb/context'
require 'travis/honeycomb/sidekiq'

module Travis
  module Honeycomb
    class << self
      def context
        Thread.current[:honeycomb_context] ||= Context.new
      end

      def enabled?
        ENV['HONEYCOMB_ENABLED'] == 'true'
      end

      def setup(tags = {})
        return unless enabled?

        honey_setup
        tags.each do |k,v|
          Context.tag(k, v)
        end
      end

      def honey_setup
        # initialize shared client
        honey
      end

      def always_sample!
        context.always_sample!
      end

      def clear
        context.clear
      end

      def send(event)
        return unless enabled?

        ev = honey.event
        ev.add(event)

        if context.always_sample?
          ev.sample_rate = 1
          ev.send_presampled
        else
          ev.send
        end
      end

      def honey
        @honey ||= Libhoney::Client.new(
          writekey:    ENV['HONEYCOMB_WRITEKEY'],
          dataset:     ENV['HONEYCOMB_DATASET'],
          sample_rate: ENV['HONEYCOMB_SAMPLE_RATE']&.to_i || 1,
        )
      end
    end
  end
end
