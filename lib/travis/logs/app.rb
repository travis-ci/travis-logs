require 'multi_json'

require 'travis'
require 'travis/support'
require 'core_ext/module/load_constants'
require 'timeout'
require 'sidekiq'

$stdout.sync = true

require 'travis/task'

# TODO why the hell does the setter below not work
module Travis
  class Task
    class << self
      def run_local?
        true
      end
    end
  end
end

module Travis
  module Logs
    autoload :Handler, 'travis/logs/handler'

    class App
      extend Exceptions::Handling
      include Logging

      def start
        preload_constants
        setup
        subscribe
      end

      private

        def preload_constants
          [Travis::Logs, Travis].each do |target|
            target.load_constants!(skip: [/::AssociationCollection$/])
          end
        end

        def setup
          Travis::Async.enabled = true
          Travis::Amqp.config = Travis.config.amqp
          Travis::Task.run_local = true # don't pipe log updates through travis_tasks
          # Travis::Async::Sidekiq.setup(Travis.config.redis.url, Travis.config.sidekiq)

          Travis::Features.start
          Travis::Database.connect
          Travis::Exceptions::Reporter.start
          Travis::Notification.setup
          Travis::Addons.register

          Travis::LogSubscriber::ActiveRecordMetrics.attach

          Travis::Memory.new(:logs).report_periodically if Travis.env == 'production'

          NewRelic.start if File.exists?('config/newrelic.yml')
        end

        def subscribe
          info 'Subscribing to amqp ...'
          info "Subscribing to reporting.jobs.#{queue_name}"

          Travis::Amqp::Consumer.jobs(queue_name).subscribe(ack: true, declare: true) do |msg, payload|
            receive(:route, msg, payload)
          end

          0.upto(Travis.config.logs.shards - 1).each do |shard|
            name = queue_name(shard)
            info "Subscribing to reporting.jobs.#{name}"
            Travis::Amqp::Consumer.jobs(name).subscribe(ack: true, declare: true) do |msg, payload|
              receive(:log, msg, payload)
            end
          end
        end

        def receive(type, message, payload)
          return unless payload = decode(payload)
          Travis.uuid = payload['uuid']
          handle(type, payload)
        rescue Exception => e
          puts "!!!FAILSAFE!!! #{e.message}", e.backtrace
        ensure
          message.ack
        end

        def handle(type, payload)
          timeout do
            Travis::Logs::Handler.handle(type, payload)
          end
        end
        rescues :handle, from: Exception unless Travis.env == 'test'

        def timeout(&block)
          Timeout::timeout(60, &block)
        end

        def decode(payload)
          MultiJson.decode(payload)
        rescue StandardError => e
          error "[#{Thread.current.object_id}] [decode error] payload could not be decoded with engine #{MultiJson.engine.to_s} (#{e.message}): #{payload.inspect}"
          nil
        end

        def queue_number
          ENV['LOGS_QUEUE']
        end

        def queue_name(shard = nil)
          number = queue_number

          name = 'logs'
          name = "#{name}-#{number}" if number
          name = "#{name}.#{shard}"  if shard
          name
        end
    end
  end
end
