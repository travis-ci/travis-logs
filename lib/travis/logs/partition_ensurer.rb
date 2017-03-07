module Travis
  module Logs
    class PartitionEnsurer
      def initialize(argv: ARGV)
        @argv = argv
      end

      attr_reader :argv
      private :argv

      attr_accessor :table_name_suffix, :logs_id_start
      attr_accessor :log_parts_id_start, :noop

      def run
        parse_argv
        sql = generate_structure_sql

        if noop
          $stdout.puts '-- SQL:'
          $stdout.puts sql
          $stdout.puts
        else
          db.transaction { db.run(sql) }
        end

        $stdout.puts '// partial json config:'
        $stdout.puts JSON.pretty_generate(partial_config)
      end

      private def db
        @db ||= begin
                  require 'travis/logs'
                  require 'travis/logs/helpers/database'
                  Travis::Logs::Helpers::Database.create_sequel
                end
      end

      private def parse_argv
        captured = {
          table_name_suffix: nil,
          logs_id_start: nil,
          log_parts_id_start: nil,
          noop: false
        }

        OptionParser.new do |opts|
          opts.separator ''
          opts.separator 'Required:'
          opts.on(
            '-s=SUFFIX', '--table-name-suffix=SUFFIX',
            'Suffix used on partitions of "logs" and "log_parts" tables'
          ) do |v|
            captured[:table_name_suffix] = v.strip
          end

          opts.on(
            '--logs-id-start=LOGS_ID_START',
            Integer,
            'Starting number for logs id sequence'
          ) do |v|
            captured[:logs_id_start] = Integer(v)
          end

          opts.on(
            '--log-parts-id-start=LOG_PARTS_ID_START',
            Integer,
            'Starting number for log_parts id sequence'
          ) do |v|
            captured[:log_parts_id_start] = Integer(v)
          end

          opts.separator 'Optional:'
          opts.on(
            '-n', '--noop',
            'Echo sql instead of executing'
          ) do
            captured[:noop] = true
          end
        end.parse!(argv)

        %i(
          table_name_suffix
          logs_id_start
          log_parts_id_start
        ).each do |k|
          raise OptionParser::MissingArgument, k if captured[k].nil?
        end

        captured.each do |attr, value|
          send(:"#{attr}=", value)
        end
      end

      private def logs_table
        "logs#{table_name_suffix}"
      end

      private def log_parts_table
        "log_parts#{table_name_suffix}"
      end

      private def generate_structure_sql
        ret = ''

        log_parts_table_exists = db.table_exists?(log_parts_table)
        logs_table_exists = db.table_exists?(logs_table)

        if log_parts_table_exists
          $stderr.puts "WARNING: Table #{log_parts_table} already exists"
        else
          ret << <<~SQL
            CREATE TABLE #{log_parts_table} (
                id bigint NOT NULL,
                log_id integer NOT NULL,
                content text,
                number integer,
                final boolean,
                created_at timestamp without time zone
            );

            CREATE SEQUENCE #{log_parts_table}_id_seq
                START WITH #{log_parts_id_start}
                MINVALUE #{log_parts_id_start};

            ALTER SEQUENCE #{log_parts_table}_id_seq
                OWNED BY #{log_parts_table}.id;

          SQL
        end

        if logs_table_exists
          $stderr.puts "WARNING: Table #{logs_table} already exists"
        else
          ret << <<~SQL
            CREATE TABLE #{logs_table} (
                id integer NOT NULL,
                job_id integer,
                content text,
                removed_by integer,
                created_at timestamp without time zone,
                updated_at timestamp without time zone,
                aggregated_at timestamp without time zone,
                archived_at timestamp without time zone,
                purged_at timestamp without time zone,
                removed_at timestamp without time zone,
                archiving boolean,
                archive_verified boolean
            );

            CREATE SEQUENCE #{logs_table}_id_seq
                START WITH #{logs_id_start}
                MINVALUE #{logs_id_start};

            ALTER SEQUENCE #{logs_table}_id_seq
                OWNED BY #{logs_table}.id;

          SQL
        end

        ret << <<~SQL
          ALTER TABLE ONLY #{log_parts_table}
              ALTER COLUMN id
              SET DEFAULT nextval('#{log_parts_table}_id_seq'::regclass);

          ALTER TABLE ONLY #{logs_table}
              ALTER COLUMN id
              SET DEFAULT nextval('#{logs_table}_id_seq'::regclass);

        SQL

        unless logs_table_exists
          ret << <<~SQL
            ALTER TABLE ONLY #{logs_table}
                ADD CONSTRAINT #{logs_table}_pkey
                PRIMARY KEY (id);

          SQL
        end

        unless log_parts_table_exists
          ret << <<~SQL
            ALTER TABLE ONLY #{log_parts_table}
                ADD CONSTRAINT #{log_parts_table}_pkey
                PRIMARY KEY (id);

          SQL
        end

        ret << <<~SQL
          CREATE INDEX IF NOT EXISTS index_#{log_parts_table}_on_created_at
              ON #{log_parts_table} USING btree (created_at);

          CREATE INDEX IF NOT EXISTS index_#{log_parts_table}_on_log_id_and_number
              ON #{log_parts_table} USING btree (log_id, number);

          CREATE INDEX IF NOT EXISTS index_#{logs_table}_on_archive_verified
              ON #{logs_table} USING btree (archive_verified);

          CREATE INDEX IF NOT EXISTS index_#{logs_table}_on_archived_at
              ON #{logs_table} USING btree (archived_at);

          CREATE INDEX IF NOT EXISTS index_#{logs_table}_on_job_id
              ON #{logs_table} USING btree (job_id);

        SQL

        ret
      end

      private def partial_config
        require 'travis/logs/helpers/database_table_lookup'
        int_max = Travis::Logs::Helpers::DatabaseTableLookup::INT_MAX
        {
          logs: {
            log_id: [
              {
                range: [0, logs_id_start - 1],
                table: 'logs'
              },
              {
                range: [logs_id_start, int_max],
                table: logs_table
              }
            ]
          },
          log_parts: {
            log_id: [
              {
                range: [0, log_parts_id_start - 1],
                table: 'log_parts'
              },
              {
                range: [log_parts_id_start, int_max],
                table: log_parts_table
              }
            ]
          }
        }
      end
    end
  end
end
