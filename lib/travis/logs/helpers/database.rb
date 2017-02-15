def jruby?
  RUBY_PLATFORM =~ /^java/
end

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
        # This method should only be called for "maintenance" tasks (such as
        # creating the tables or debugging).
        def self.create_sequel
          config = Travis::Logs.config.logs_database.to_h
          uri = jdbc_uri_from_config(config) if jruby?
          uri = uri_from_config(config) unless jruby?

          after_connect = proc do |c|
            if c.respond_to?(:execute)
              c.execute("SET application_name TO 'logs'")
            elsif c.respond_to?(:exec)
              c.exec("SET application_name TO 'logs'")
            end
          end

          Sequel.default_timezone = :utc
          Sequel.connect(uri, max_connections: config[:pool], after_connect: after_connect)
        end

        def self.uri_from_config(config)
          host = config[:host] || 'localhost'
          port = config[:port] || 5432
          database = config[:database]
          username = config[:username] || ENV['USER']

          params = {
            user: username,
            password: config[:password]
          }

          "postgres://#{host}:#{port}/#{database}?#{URI.encode_www_form(params)}"
        end

        def self.jdbc_uri_from_config(config)
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

          "jdbc:postgresql://#{host}:#{port}/#{database}?#{URI.encode_www_form(params)}"
        end

        def self.connect
          new.tap(&:connect)
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

        def log_for_id(log_id)
          @db.call(:find_log, log_id: log_id).first
        end

        def log_id_for_job_id(job_id)
          log = @db.call(:find_log_id, job_id: job_id)
          log[:id] if log
        end

        def log_content_length_for_id(log_id)
          @db[:logs].select { [id, job_id, octet_length(content).as(content_length)] }.where(id: log_id).first
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
          @db.call(:create_log,             job_id: job_id,
                                            created_at: Time.now.utc,
                                            updated_at: Time.now.utc)
        end

        def create_log_part(params)
          @db.call(:create_log_part, params.merge(created_at: Time.now.utc))
        end

        def delete_log_parts(log_id)
          @db.call(:delete_log_parts, log_id: log_id)
        end

        def set_log_content(log_id, content)
          delete_log_parts(log_id)
          aggregated_at = Time.now.utc unless content.nil?
          @db[:logs].where(id: log_id).update(content: content, aggregated_at: aggregated_at, archived_at: nil, archive_verified: nil, updated_at: Time.now.utc)
        end

        AGGREGATEABLE_SELECT_SQL = <<-SQL.split.join(' ')
          SELECT log_id
            FROM log_parts
           WHERE (created_at <= NOW() - interval '? seconds' AND final = ?)
              OR  created_at <= NOW() - interval '? seconds'
           LIMIT ?
        SQL

        def aggregatable_log_parts(regular_interval, force_interval, limit)
          @db[AGGREGATEABLE_SELECT_SQL, regular_interval, true, force_interval, limit].map(:log_id).uniq
        end

        AGGREGATE_PARTS_SELECT_SQL = <<-SQL.split.join(' ')
          SELECT array_to_string(array_agg(log_parts.content ORDER BY number, id), '')
            FROM log_parts
           WHERE log_id = ?
        SQL

        AGGREGATE_UPDATE_SQL = <<-SQL.split.join(' ')
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
          @db[:logs].select(:id).where(job_id: :$job_id).prepare(:first, :find_log_id)
          @db[:logs].prepare(:insert, :create_log,             job_id: :$job_id,
                                                               created_at: :$created_at,
                                                               updated_at: :$updated_at)
          @db[:log_parts].prepare(:insert, :create_log_part,             log_id: :$log_id,
                                                                         content: :$content,
                                                                         number: :$number,
                                                                         final: :$final,
                                                                         created_at: :$created_at)
          @db[:log_parts].where(log_id: :$log_id).prepare(:delete, :delete_log_parts)
        end
      end
    end
  end
end
