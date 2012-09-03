require 'bunny'
require 'hashr'

module Travis
  module Amqp
    class Consumer
      class Message
        attr_reader :headers, :queue

        def initialize(data)
          @headers = data
        end

        def ack
          # already done by the bunny subscription
        end
      end

      class << self
        def threads
          @threads ||= []
        end

        def wait
          threads.each(&:join)
        end
      end

      include Logging

      DEFAULTS = {
        :subscribe => { :ack => false },
        :queue     => { :prefetch_count => 1, :durable => true },
      }

      attr_reader :name, :options, :subscription

      def initialize(name, options = {})
        @name    = name
        @options = Hashr.new(DEFAULTS.deep_merge(options))
      end

      def subscribe(options = {}, &block)
        options = deep_merge(self.options.subscribe, options)
        debug "subscribing to #{name.inspect} with #{options.inspect}"

        self.class.threads << Thread.new {
          begin
            queue.subscribe(options) do |data|
              block.call(Message.new(data), data[:payload])
            end
          rescue Exception => e
            puts e.message, e.backtrace
          end
        }
      end

      def unsubscribe
        debug "unsubscribing from #{name.inspect}"
        queue.unsubscribe
      end

      protected

        def queue
          @queue ||= Amqp.connection.queue(name, options.queue)
        end

        def deep_merge(hash, other)
          hash.merge(other, &(merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }))
        end
    end
  end
end
