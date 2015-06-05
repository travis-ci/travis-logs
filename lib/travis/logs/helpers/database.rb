require 'sequel'
require 'jdbc/postgres'
require "delegate"
require "active_support/core_ext/string/filters"

module Travis
  module Logs
    module Helpers
      # The Database helper talks to the Postgres database.
      #
      # No database-specific logic (such as table names and SQL queries) should
      # be outside of this class.
      class Database
        # This method should only be called for "maintenance" tasks (such as
        # creating the tables or debugging).
        def self.create_sequel
          config = Travis::Logs.config.logs_database
          Sequel.connect(jdbc_uri_from_config(config), max_connections: config[:pool])
        end

        def self.jdbc_uri_from_config(config)
          host = config[:host] || 'localhost'
          port = config[:port] || 5432
          database = config[:database]
          username = config[:username] || ENV["USER"]

          "jdbc:postgresql://#{host}:#{port}/#{database}?user=#{username}&password=#{config[:password]}"
        end

        def self.connect
          new.tap(&:connect)
        end

        def initialize
          @db = self.class.create_sequel
        end

        def connect
          @db.test_connection
          @db << "SET application_name = 'logs'"
          prepare_statements
        end

        def log_for_id(log_id)
          @db.call(:find_log, log_id: log_id).first
        end

        def log_for_job_id(job_id)
          @db.call(:find_log_id, job_id: job_id).first
        end

        def log_content_length_for_id(log_id)
          @db[:logs].select{[id, job_id, octet_length(content).as(content_length)]}.where(id: log_id).first
        end

        def update_archiving_status(log_id, archiving)
          @db[:logs].where(id: log_id).update(archiving: archiving)
        end

        def mark_archive_verified(log_id)
          @db[:logs].where(id: log_id).update(archived_at: Time.now.utc, archive_verified: true)
        end

        def mark_not_archived(log_id)
          @db[:logs].where(id: log_id).update(archived_at: nil, archive_verified: false)
        end

        def purge(log_id)
          @db[:logs].where(id: log_id).update(purged_at: Time.now.utc, content: nil)
        end

        def create_log(job_id)
          @db.call(:create_log, {
            job_id: job_id,
            created_at: Time.now.utc,
            updated_at: Time.now.utc
          })
        end

        def create_log_part(params)
          @db.call(:create_log_part, params.merge(created_at: Time.now.utc))
        end

        def delete_log_parts(log_id)
          @db.call(:delete_log_parts, log_id: log_id)
        end

        AGGREGATEABLE_SELECT_SQL = <<-SQL.squish
          SELECT DISTINCT log_id
            FROM log_parts
           WHERE (created_at <= NOW() - interval '? seconds' AND final = ?)
              OR  created_at <= NOW() - interval '? seconds'
        SQL

        def aggregatable_log_parts(regular_interval, force_interval)
          @db[AGGREGATEABLE_SELECT_SQL, regular_interval, true, force_interval].map(:log_id)
        end

        AGGREGATE_PARTS_SELECT_SQL = <<-SQL.squish
          SELECT array_to_string(array_agg(log_parts.content ORDER BY number, id), '')
            FROM log_parts
           WHERE log_id = ?
        SQL

        AGGREGATE_UPDATE_SQL = <<-SQL.squish
          UPDATE logs
             SET aggregated_at = ?,
                 content = (COALESCE(content, '') || (#{AGGREGATE_PARTS_SELECT_SQL}))
           WHERE logs.id = ?
        SQL

        def aggregate(log_id)
          @db[AGGREGATE_UPDATE_SQL, Time.now.utc, log_id, log_id].update
        end

        def transaction(&block)
          @db.transaction(&block)
        end

        private

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
          @db[:log_parts].where(log_id: :$log_id).prepare(:delete, :delete_log_parts)
        end
      end
    end
  end
end
