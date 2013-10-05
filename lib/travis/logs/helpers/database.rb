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
          prepare_statements
        end

        def log_for_id(log_id)
          @db.call(:find_log, log_id: log_id).first
          @db[:logs].where(id: log_id).first
        end

        def log_for_job_id(job_id)
          @db.call(:find_log_id, job_id: job_id).first
        end

        def mark_as_archiving(log_id, archiving)
          @db[:logs].where(id: log_id).update(archiving: archiving)
        end

        def mark_archive_verified(log_id)
          @db[:logs].where(id: log_id).update(archived_at: Time.now.utc, archive_verified: true)
        end

        def create_log(job_id)
          @db.call(:create_log, job_id: job_id, created_at: Time.now, updated_at: Time.now.utc)
        end

        def create_log_part(params)
          @db.call(:create_log_part, params.merge(created_at: Time.now.utc))
        end

        # For compatibility API
        # TODO: Remove these when all Sequel calls are handled in this class

        def [](table)
          @db[table]
        end

        def call(*args)
          @db.call(*args)
        end

        def create_table(*args, &block)
          @db.create_table(*args, &block)
        end

        def drop_table(*args)
          @db.drop_table(*args)
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

        def prepare_statements
          @db[:logs].where(id: :$log_id).prepare(:select, :find_log)
          @db[:logs].select(:id).where(job_id: :$job_id).prepare(:select, :find_log_id)
          @db[:logs].prepare(:insert, :create_log, {
            job_id: :$job_id,
            created_at: :$created_at,
            updated_at: :$updated_at,
          })
          @db[:log_parts].prepare(:insert, :create_log_part, {
            log_id: :$log_id,
            content: :$content,
            number: :$number,
            final: :$final,
            created_at: :$created_at,
          })
        end
      end
    end
  end
end
