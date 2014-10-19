require 'travis/logs/config'

module Travis
  def self.config
    Logs.config
  end

  module Logs
    def self.config
      @config ||= Config.load
    end

    def self.database_connection=(connection)
      @database_connection = connection
    end

    def self.database_connection
      @database_connection
    end
  end
end
