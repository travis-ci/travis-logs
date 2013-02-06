require 'coder'

module Travis
  module Logs
    class Receive
      class Queue
        include Logging

        def self.subscribe(name, &handler)
          new(name, &handler).subscribe
        end

        attr_reader :name, :handler

        def initialize(name, &handler)
          @name = name
          @handler = handler
        end

        def subscribe
          Travis::Amqp::Consumer.jobs(name).subscribe(:ack => true, declare: true, &method(:receive))
        end

        private

          def receive(message, payload)
            failsafe(message, payload) do
              payload = decode(payload) || raise("no payload #{message.inspect}")
              Travis.uuid = payload.delete('uuid')
              handler.call(payload)
            end
          end

          def failsafe(message, payload, options = {}, &block)
            Timeout::timeout(options[:timeout] || 60, &block)
          rescue Exception => e
            begin
              puts e.message, e.backtrace
              Travis::Exceptions.handle(e)
            rescue Exception => e
              puts "!!!FAILSAFE!!! #{e.message}", e.backtrace
            end
          ensure
            message.ack
          end

          def decode(payload)
            cleaned = Coder.clean(payload)
            MultiJson.decode(cleaned)
          rescue StandardError => e
            error "[decode error] payload could not be decoded with engine #{MultiJson.engine.to_s}: #{e.inspect} #{payload.inspect}"
            nil
          end
      end
    end
  end
end
