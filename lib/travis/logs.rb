require 'travis/logs/config'

module Travis
  def self.config
    Travis::Logs.config
  end

  module Logs
    class << self
      def config
        @config ||= Travis::Logs::Config.load
      end

      attr_writer :config
      attr_accessor :database_connection
    end
  end
end
