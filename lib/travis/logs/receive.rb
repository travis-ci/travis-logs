require 'multi_json'

require 'travis'
require 'core_ext/module/load_constants'
require 'timeout'
require 'sidekiq'

$stdout.sync = true

module Travis
  module Logs
    class Receive
      autoload :Queue, 'travis/logs/receive/queue'

      def setup
        Travis::Async.enabled = true
        Travis::Amqp.config = Travis.config.amqp
        Travis::Addons::Pusher::Task.run_local = true # don't pipe log updates through travis_tasks

        Travis::Database.connect
        Travis::Exceptions::Reporter.start
        Travis::Notification.setup
        Travis::Addons.register

        Travis::LogSubscriber::ActiveRecordMetrics.attach
        Travis::Memory.new(:logs).report_periodically if Travis.env == 'production'
      end

      def run
        Queue.subscribe(queue_name, &method(:route))
        0.upto(shards).each do |shard|
          Queue.subscribe(queue_name(shard), &method(:receive))
        end
      end

      private

        def route(payload)
          shard = payload['id'].to_i % shards
          queue = queue_name(shard)
          payload.update(uuid: Travis.uuid)
          Travis::Amqp::Publisher.jobs(queue).publish(payload)
        end

        def receive(payload)
          Travis.run_service(:logs_append, data: payload)
        end

        def queue_name(shard = nil)
          name = ['logs']
          name << number      if number
          name << ".#{shard}" if shard
          name.join
        end

        def shards
          Travis.config.logs.shards - 1
        end

        def number
           ENV['LOGS_QUEUE']
        end
    end
  end
end
