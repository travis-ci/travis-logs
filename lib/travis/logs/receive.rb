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
        Travis.config.logs.shards = 20

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
        0.upto(Travis.config.logs.threads || 10).each do
          Queue.subscribe('logs', &method(:receive))
        end
      end

      private

        def receive(payload)
          Travis.run_service(:logs_receive, data: payload)
        end
    end
  end
end
