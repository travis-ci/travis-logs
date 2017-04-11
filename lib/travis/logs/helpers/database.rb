# frozen_string_literal: true

require 'logger'
require 'sequel'
require 'pg'
require 'travis/logs/helpers/database_vacuum_settings'

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

            Sequel.default_timezone = :utc
            conn = Sequel.connect(
              config[:url],
              max_connections: config[:pool],
              after_connect: ->(c) { after_connect(c) }
            )
            conn.loggers << Logger.new($stdout) if config[:sql_logging]
            conn
          end

          def connect
            new.tap(&:connect)
          end

          def vacuum_settings(config: Travis::Logs.config.logs_database.to_h,
                              statements: DatabaseVacuumSettings::STATEMENTS)
            db = new.db
            variables = config.merge(
              database: db['SELECT current_database()'].first
                                                       .fetch(:current_database)
            )
            statements.each do |statement|
              db.execute(statement.split.join(' ') % variables)
            end
          end

          private def after_connect(conn)
            execute_compat(
              conn, "SET application_name = '#{application_name}'"
            )
            execute_compat(
              conn, "SET statement_timeout = #{statement_timeout_ms}"
            )
          end

          private def application_name
            @application_name ||= [
              'logs', Travis.config.env, ENV['DYNO']
            ].compact.join('.')
          end

          private def statement_timeout_ms
            @statement_timeout_ms ||= if ENV['DYNO'].to_s.start_with?('web.')
                                        30 * 1_000
                                      else
                                        30 * 60 * 1_000
                                      end
          end

          private def execute_compat(conn, statement)
            if conn.respond_to?(:exec)
              conn.exec(statement)
            elsif conn.respond_to?(:execute)
              conn.execute(statement)
            elsif conn.respond_to?(:create_statement)
              st = conn.create_statement
              st.execute(statement)
              st.close
            end
          end
        end

        def initialize
          @db = self.class.create_sequel
          Travis.logger.info(
            'new database connection',
            object_id: object_id,
            max_size: db.pool.max_size
          )
        end

        attr_reader :db

        def connect
          db.test_connection

          # TODO: run prepare_statements for every connection,
          # not just the first connection in the pool
          # see also: Sequel.connect, after_connect
          prepare_statements
        end

        def now
          db['select now()'].first.fetch(:now)
        end

        def log_for_id(log_id)
          db.call(:find_log, log_id: log_id)
        end

        def log_id_for_job_id(job_id)
          log = db.call(:find_log_id, job_id: job_id)
          log[:id] if log
        end

        def log_for_job_id(job_id)
          db.call(:find_log_by_job_id, job_id: job_id)
        end

        def log_content_length_for_id(log_id)
          db[:logs]
            .select { [id, job_id, octet_length(content).as(content_length)] }
            .where(id: log_id).first
        end

        def update_archiving_status(log_id, archiving)
          db[:logs].where(id: log_id).update(archiving: archiving)
        end

        def mark_archive_verified(log_id)
          db[:logs]
            .where(id: log_id)
            .update(archived_at: Time.now.utc, archive_verified: true)
        end

        def mark_not_archived(log_id)
          db[:logs]
            .where(id: log_id)
            .update(archived_at: nil, archive_verified: false)
        end

        def purge(log_id)
          db[:logs]
            .where(id: log_id)
            .update(purged_at: Time.now.utc, content: nil)
        end

        def create_log(job_id)
          db.call(
            :create_log,
            job_id: job_id,
            created_at: Time.now.utc,
            updated_at: Time.now.utc
          )
        end

        def create_log_part(params)
          db.call(:create_log_part, params.merge(created_at: Time.now.utc))
        end

        def delete_log_parts(log_id)
          db.call(:delete_log_parts, log_id: log_id)
        end

        def log_parts(log_id, after: nil, part_numbers: [])
          query = db[:log_parts].select(:id, :number, :content, :final)
                                .where(log_id: log_id)
          query = query.where { number > after } if after
          query = query.where(number: part_numbers) unless part_numbers.empty?
          query.order(:number).to_a
        end

        def set_log_content(log_id, content, removed_by: nil)
          transaction do
            delete_log_parts(log_id)
            aggregated_at = Time.now.utc unless content.nil?
            removed_at = Time.now.utc unless removed_by.nil?
            db.call(:set_log_content,
                    log_id: log_id,
                    content: content,
                    aggregated_at: aggregated_at,
                    archived_at: nil,
                    archive_verified: nil,
                    updated_at: Time.now.utc,
                    removed_by: removed_by,
                    removed_at: removed_at)
          end
        end

        def aggregatable_logs(regular_interval, force_interval, limit,
                              order: :created_at)
          query = db[:log_parts]
                  .select(:log_id)
                  .where { created_at <= (Time.now.utc - regular_interval) }
                  .and(final: true)
                  .or { created_at <= (Time.now.utc - force_interval) }
                  .limit(limit)
          query = query.order(order.to_sym) unless order.nil?
          query.map(:log_id).uniq
        end

        def min_log_part_id
          db['SELECT min(id) AS id FROM log_parts'].first[:id]
        end

        AGGREGATABLE_SELECT_WITH_MIN_ID_SQL = <<-SQL.split.join(' ').freeze
          SELECT id, log_id
            FROM log_parts
           WHERE id BETWEEN ? AND ?
           ORDER BY id
        SQL

        def aggregatable_logs_page(cursor, per_page)
          db[
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
          db[AGGREGATE_UPDATE_SQL, Time.now.utc, log_id, log_id].update
        end

        def aggregated_on_demand(log_id)
          db[
            AGGREGATE_PARTS_SELECT_SQL,
            log_id
          ].first.fetch(:array_to_string, '') || ''
        end

        def transaction(&block)
          db.transaction(&block)
        end

        private def prepare_statements
          prepare_logs_statements
          prepare_log_parts_statements
        end

        private def prepare_logs_statements
          db[:logs]
            .where(id: :$log_id)
            .prepare(:first, :find_log)

          db[:logs]
            .select(:id)
            .where(job_id: :$job_id)
            .prepare(:first, :find_log_id)

          db[:logs]
            .where(job_id: :$job_id)
            .prepare(:first, :find_log_by_job_id)

          db[:logs]
            .prepare(:insert, :create_log,
                     job_id: :$job_id, created_at: :$created_at,
                     updated_at: :$updated_at)

          db[:logs]
            .where(id: :$log_id)
            .returning
            .prepare(:update, :set_log_content,
                     content: :$content,
                     aggregated_at: :$aggregated_at,
                     archived_at: :$archived_at,
                     archive_verified: :$archive_verified,
                     updated_at: :$updated_at,
                     removed_by: :$removed_by,
                     removed_at: :$removed_at)
        end

        private def prepare_log_parts_statements
          db[:log_parts]
            .prepare(:insert, :create_log_part,
                     log_id: :$log_id, content: :$content,
                     number: :$number, final: :$final,
                     created_at: :$created_at)

          db[:log_parts]
            .where(log_id: :$log_id)
            .prepare(:delete, :delete_log_parts)
        end
      end
    end
  end
end
