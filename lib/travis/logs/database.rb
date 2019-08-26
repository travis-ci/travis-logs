# frozen_string_literal: true

require 'logger'
require 'sequel'
require 'pg'

require 'travis/logs'

module Travis
  module Logs
    class Database
      class << self
        def create_sequel(config: Travis.config.logs_database.to_h)
          Sequel.default_timezone = :utc
          conn = Sequel.connect(
            config[:url],
            max_connections: config[:pool],
            after_connect: ->(c) { after_connect(c) },
            preconnect: preconnect?
          )
          conn.loggers << Logger.new($stdout) if config[:sql_logging]
          conn
        end

        def connect(config: Travis.config.logs_database.to_h)
          new(config: config).tap(&:connect)
        end

        private def after_connect(conn)
          execute_compat(
            conn, "SET application_name = '#{Travis.config.process_name}'"
          )
          execute_compat(
            conn, "SET statement_timeout = #{statement_timeout_ms}"
          )
          execute_compat(conn, 'SET constraint_exclusion = partition')
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

        private def preconnect?
          %w[true 1].include?(ENV['PGBOUNCER_ENABLED'].to_s.downcase)
        end
      end

      def initialize(config: Travis.config.logs_database.to_h,
                     cache: Travis::Logs.cache,
                     maint: Travis::Logs::Maintenance.new)
        @db = self.class.create_sequel(config: config)
        @cache = cache
        @maint = maint
        Travis.logger.info(
          'new database connection',
          object_id: object_id,
          max_size: db.pool.max_size
        )
      end

      attr_reader :db, :cache, :maint
      private :cache
      private :maint

      def connect
        db.test_connection
      end

      def now
        db['select now()'].first.fetch(:now)
      end

      def log_for_id(log_id)
        db[:logs].where(id: log_id).first
      end

      def log_id_for_job_id(job_id)
        log = db[:logs].select(:id).where(job_id: job_id).first
        log[:id] if log
      end

      def job_id_for_log_id(log_id)
        log = db[:logs].select(:job_id).where(id: log_id).first
        log[:job_id] if log
      end

      def cached_log_id_for_job_id(job_id)
        cache_key = "log_id.#{job_id}"
        log_id = cache.read(cache_key)

        if log_id.nil?
          log_id = log_id_for_job_id(job_id)
          cache.write(cache_key, log_id) if log_id
        end

        log_id
      end

      def log_for_job_id(job_id)
        db[:logs].where(job_id: job_id).first
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
        now = Time.now.utc
        db[:logs].insert(job_id: job_id, created_at: now, updated_at: now)
      end

      def create_log_part(params)
        maint.restrict!
        db[:log_parts].insert(params.merge(created_at: Time.now.utc))
      end

      def create_log_parts(entries)
        maint.restrict!
        now = Time.now.utc
        db[:log_parts].multi_insert(
          entries.map { |e| e.merge(created_at: now) }
        )
      end

      def delete_log_parts(log_id)
        maint.restrict!
        db[:log_parts].where(log_id: log_id).delete
      end

      def log_parts(log_id, after: nil, part_numbers: [])
        maint.restrict!
        query = db[:log_parts].select(:id, :number, :content, :final)
                              .where(log_id: log_id)
        query = query.where { number > after } if after
        query = query.where(number: part_numbers) unless part_numbers.empty?
        query.order(:number).to_a
      end

      def set_log_content(log_id, content, removed_by: nil)
        db.transaction do
          delete_log_parts(log_id)
          now = Time.now.utc
          aggregated_at = now unless content.nil?
          removed_at = now unless removed_by.nil?
          db[:logs]
            .where(id: log_id)
            .returning
            .update(
              content: content,
              aggregated_at: aggregated_at,
              archived_at: nil,
              archive_verified: nil,
              updated_at: now,
              removed_by: removed_by,
              removed_at: removed_at
            )
        end
      end

      def aggregatable_logs(regular_interval, force_interval, limit,
                            order: :created_at)
        maint.restrict!
        query = db[:log_parts]
                .select(:log_id)
                .where { created_at <= (Time.now.utc - regular_interval) }
                .where(final: true)
                .or { created_at <= (Time.now.utc - force_interval) }
                .limit(limit)
        query = query.order(order.to_sym) unless order.nil?
        query.map(:log_id).uniq
      end

      def min_log_part_id
        maint.restrict!
        db['SELECT min(id) AS id FROM log_parts'].first[:id]
      end

      AGGREGATABLE_SELECT_WITH_MIN_ID_SQL = <<-SQL.split.join(' ').freeze
        SELECT id, log_id
          FROM log_parts
         WHERE id BETWEEN ? AND ?
         ORDER BY id
      SQL

      def aggregatable_logs_page(cursor, per_page)
        maint.restrict!
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
        WITH log_to_update AS (
          SELECT logs.id AS id
          FROM logs
          INNER JOIN log_parts ON log_parts.log_id = logs.id
          WHERE logs.id = ?
          GROUP BY logs.id
        )
        UPDATE logs
           SET aggregated_at = ?,
               content = (
                 COALESCE(content, '') || COALESCE((#{AGGREGATE_PARTS_SELECT_SQL}), '')
               )
         FROM log_to_update
         WHERE logs.id = log_to_update.id
      SQL

      def aggregate(log_id)
        maint.restrict!
        db[AGGREGATE_UPDATE_SQL, log_id, Time.now.utc, log_id].update
      end

      def aggregated_on_demand(log_id)
        maint.restrict!
        db[
          AGGREGATE_PARTS_SELECT_SQL,
          log_id
        ].first.fetch(:array_to_string, '') || ''
      end
    end
  end
end
