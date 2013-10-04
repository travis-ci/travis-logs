require 'sequel'
require 'jdbc/postgres'

module Travis
  module Logs
    module Helpers
      class Database
        def self.connect
          new.tap(&:connect)
        end

        def initialize
          @db = create_db
        end

        def connect
          @db.test_connection
          @db << "SET application_name = 'logs'"
        end

        def log_for_id(log_id)
          @db[:logs].where(id: log_id).first
        end

        def mark_as_archiving(log_id, archiving)
          @db[:logs].where(id: log_id).update(archiving: archiving)
        end

        def mark_archive_verified(log_id)
          @db[:logs].where(id: log_id).update(archived_at: Time.now.utc, archive_verified: true)
        end

        # For compatibility API
        # TODO: Remove these when all Sequel calls are handled in this class

        def [](table)
          @db[table]
        end

        def call(*args)
          @db.call(*args)
        end

        private

        def create_db
          Sequel.connect(connection_string, max_connections: config[:pool]).tap do |db|
            db.logger = Travis.logger unless Travis::Logs.config.env == 'production'
            db.timezone = :utc
          end
        end

        def connection_string
          "jdbc:postgresql://#{config[:host]}:#{config[:port]}/#{config[:database]}?user=#{config[:username]}&password=#{config[:password]}"
        end
        
        def config
          {
            username: ENV["USER"],
          }.merge(Travis::Logs.config.database)
        end
      end
    end
  end
end
