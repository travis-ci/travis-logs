require 'bundler/setup'
require 'travis/logs'

$stdout.sync = true

module Travis
  class Logs
    class Cli < ::Thor
      namespace 'travis:logs'

      desc 'start', 'Process build log messages'
      def start
        ENV['ENV'] || 'development'
        preload_constants!
        Travis::Logs.start
      end

      protected

        def preload_constants!
          require 'core_ext/module/load_constants'
          require 'travis'

          [Travis::Logs, Travis].each do |target|
            target.load_constants!(:skip => [/::AssociationCollection$/])
          end
        end
    end
  end
end

