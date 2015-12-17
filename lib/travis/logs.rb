module Travis
  def self.config
    Logs.config
  end

  module Logs
    autoload :Aggregate, 'travis/logs/aggregate'
    autoload :App, 'travis/logs/app'
    autoload :Config, 'travis/logs/config'
    autoload :Existence, 'travis/logs/existence'
    autoload :Receive, 'travis/logs/receive'
    autoload :Sidekiq, 'travis/logs/sidekiq'

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
