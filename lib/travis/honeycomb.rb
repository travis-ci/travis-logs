# frozen_string_literal: true

require 'libhoney'
require 'travis/honeycomb/context'
require 'travis/honeycomb/sidekiq'
require 'travis/honeycomb/rabbitmq'

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
        tags.each do |k, v|
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
        elsif context.sample_rate
          ev.sample_rate = context.sample_rate
        end
        ev.send
      end

      def honey
        @honey ||= Libhoney::Client.new(
          writekey:    Travis.config.logs.honeycomb.writekey,
          dataset:     Travis.config.logs.honeycomb.dataset,
          sample_rate: Travis.config.logs.honeycomb.sample_rate
        )
      end
    end
  end
end
