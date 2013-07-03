require 'sequel'
require 'jdbc/postgres'

module Travis
  module Logs
    module Helpers
      module Database

        def self.connect
          Travis.logger.info('Setting up database connection and preloading model columns')
          
          db = Sequel.connect(connection_string, max_connections: config[:pool])
          db.logger = Travis.logger unless Travis::Logs.config.env == 'production'
          db.timezone = :utc
          db.test_connection
          db
        end

        def self.connection_string
          extra_params = "&#{config[:extra_params]}"
          "jdbc:postgresql://#{config[:host]}:#{config[:port]}/#{config[:database]}?user=#{config[:username]}&password=#{config[:password]}"
        end
        
        def self.config
          Travis::Logs.config.database
        end
      end
    end
  end
end