def jruby?
  RUBY_PLATFORM =~ /^java/
end

require 'logger'
require 'sequel'
require 'jdbc/postgres' if jruby?
require 'pg' unless jruby?
require 'delegate'

module Travis
  module Logs
    module Helpers
      # The Database helper talks to the Postgres database.
      #
      # No database-specific logic (such as table names and SQL queries) should
      # be outside of this class.
      class Database
        class << self
          # This method should only be called for "maintenance" tasks (such as
          # creating the tables or debugging).
          def create_sequel
            config = Travis::Logs.config.logs_database.to_h
            uri = jdbc_uri_from_config(config) if jruby?
            uri = uri_from_config(config) unless jruby?

            Sequel.default_timezone = :utc
            conn = Sequel.connect(
              uri,
              max_connections: config[:pool],
              after_connect: ->(c) { after_connect(c) }
            )
            conn.loggers << Logger.new($stdout) if config[:sql_logging]
            conn
          end

          def uri_from_config(config)
            host = config[:host] || 'localhost'
            port = config[:port] || 5432
            database = config[:database]
            username = config[:username] || ENV['USER']

            params = {
              user: username,
              password: config[:password]
            }

            enc_params = URI.encode_www_form(params)
            "postgres://#{host}:#{port}/#{database}?#{enc_params}"
          end

          def jdbc_uri_from_config(config)
            host = config[:host] || 'localhost'
            port = config[:port] || 5432
            database = config[:database]
            username = config[:username] || ENV['USER']

            params = {
              user: username,
              password: config[:password]
            }

            if config[:ssl]
              params[:ssl] = true
              params[:sslfactory] = 'org.postgresql.ssl.NonValidatingFactory'
            end

            enc_params = URI.encode_www_form(params)
            "jdbc:postgresql://#{host}:#{port}/#{database}?#{enc_params}"
          end

          def connect
            new.tap(&:connect)
          end

          def after_connect(conn)
            command = "SET application_name TO '#{application_name}'"
            if conn.respond_to?(:exec)
              conn.exec(command)
            elsif conn.respond_to?(:execute)
              conn.execute(command)
            elsif conn.respond_to?(:create_statement)
              st = conn.create_statement
              st.execute(command)
              st.close
            end
          end

          def application_name
            @application_name ||= [
              'logs', Travis.env, ENV['DYNO']
            ].compact.join('.')
          end
        end

        def initialize
          @db = self.class.create_sequel
        end

        def connect
          @db.test_connection

          # TODO: run prepare_statements for every connection,
          # not just the first connection in the pool
          # see also: Sequel.connect, after_connect
          prepare_statements
        end

        def now
          @db['select now()'].first.fetch(:now)
        end

        def log_for_id(log_id)
          @db.call(:find_log, log_id: log_id).first
        end

        def log_id_for_job_id(job_id)
          log = @db.call(:find_log_id, job_id: job_id)
          log[:id] if log
        end

        def log_for_job_id(job_id)
          @db.call(:find_log_by_job_id, job_id: job_id).first
        end

        def log_content_length_for_id(log_id)
          @db[:logs]
            .select { [id, job_id, octet_length(content).as(content_length)] }
            .where(id: log_id).first
        end

        def update_archiving_status(log_id, archiving)
          @db[:logs].where(id: log_id).update(archiving: archiving)
        end

        def mark_archive_verified(log_id)
          @db[:logs]
            .where(id: log_id)
            .update(archived_at: Time.now.utc, archive_verified: true)
        end

        def mark_not_archived(log_id)
          @db[:logs]
            .where(id: log_id)
            .update(archived_at: nil, archive_verified: false)
        end

        def purge(log_id)
          @db[:logs]
            .where(id: log_id)
            .update(purged_at: Time.now.utc, content: nil)
        end

        def create_log(job_id)
          @db.call(
            :create_log,
            job_id: job_id,
            created_at: Time.now.utc,
            updated_at: Time.now.utc
          )
        end

        def create_log_part(params)
          @db.call(:create_log_part, params.merge(created_at: Time.now.utc))
        end

        def delete_log_parts(log_id)
          @db.call(:delete_log_parts, log_id: log_id)
        end

        def set_log_content(log_id, content, removed_by: nil)
          delete_log_parts(log_id)
          aggregated_at = Time.now.utc unless content.nil?
          removed_at = Time.now.utc unless removed_by.nil?
          @db[:logs].where(id: log_id)
                    .update(content: content, aggregated_at: aggregated_at,
                            archived_at: nil, archive_verified: nil,
                            updated_at: Time.now.utc,
                            removed_by: removed_by, removed_at: removed_at)
        end

        def aggregatable_logs(regular_interval, force_interval, limit,
                              order: :created_at)
          query = @db[:log_parts]
                  .select(:log_id)
                  .where(
                    "created_at <= NOW() - interval '? seconds' AND final = ?",
                    regular_interval, true
                  )
                  .or(
                    "created_at <= NOW() - interval '? seconds'",
                    force_interval
                  )
                  .limit(limit)
          query = query.order(order.to_sym) unless order.nil?
          query.map(:log_id).uniq
        end

        def min_log_part_id
          @db['SELECT min(id) AS id FROM log_parts'].first[:id]
        end

        def max_log_part_number_for_log(log_id)
          (
            @db[
              'SELECT MAX(number) AS number FROM log_parts WHERE log_id = ?',
              log_id
            ].first || {}
          )[:number] || 0
        end

        AGGREGATABLE_SELECT_WITH_MIN_ID_SQL = <<-SQL.split.join(' ').freeze
          SELECT id, log_id
            FROM log_parts
           WHERE id BETWEEN ? AND ?
           ORDER BY id
        SQL

        def aggregatable_logs_page(cursor, per_page)
          @db[
            AGGREGATABLE_SELECT_WITH_MIN_ID_SQL,
            cursor, cursor + per_page
          ].map(:log_id).uniq
        end

        AGGREGATE_PARTS_SELECT_SQL = <<-SQL.split.join(' ').freeze
          SELECT array_to_string(
                   array_agg(log_parts.content ORDER BY number, id), ''
                 )
            FROM log_parts
           WHERE log_id = ?
        SQL

        AGGREGATE_UPDATE_SQL = <<-SQL.split.join(' ').freeze
          UPDATE logs
             SET aggregated_at = ?,
                 content = (
                   COALESCE(content, '') || (#{AGGREGATE_PARTS_SELECT_SQL})
                 )
           WHERE logs.id = ?
        SQL

        def aggregate(log_id)
          @db[AGGREGATE_UPDATE_SQL, Time.now.utc, log_id, log_id].update
        end

        def aggregated_on_demand(log_id)
          @db[
            AGGREGATE_PARTS_SELECT_SQL,
            log_id
          ].first.fetch(:array_to_string, '') || ''
        end

        def transaction(&block)
          @db.transaction(&block)
        end

        private def prepare_statements
          @db[:logs]
            .where(id: :$log_id)
            .prepare(:select, :find_log)

          @db[:logs]
            .select(:id)
            .where(job_id: :$job_id)
            .prepare(:first, :find_log_id)

          @db[:logs]
            .where(job_id: :$job_id)
            .prepare(:select, :find_log_by_job_id)

          @db[:logs]
            .prepare(:insert, :create_log,
                     job_id: :$job_id, created_at: :$created_at,
                     updated_at: :$updated_at)

          @db[:log_parts]
            .prepare(:insert, :create_log_part,
                     log_id: :$log_id, content: :$content,
                     number: :$number, final: :$final,
                     created_at: :$created_at)

          @db[:log_parts]
            .where(log_id: :$log_id)
            .prepare(:delete, :delete_log_parts)
        end
      end
    end
  end
end
