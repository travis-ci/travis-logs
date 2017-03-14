# frozen_string_literal: true

module Travis
  module Logs
    module Helpers
      class DatabaseTableMapper
        PARTITION_TABLE_RE = /^(?<table>logs|log_parts)(?:[0-9]*)$/.freeze
        NEXTVAL_SEQ_RE = /^nextval\('(?<seq>[a-z0-9_]+)'::regclass\)$/.freeze
        INT_MAX = 9_223_372_036_854_775_807
        DEFAULT_MAPPING = {
          logs: {
            log_id: [
              {
                range: [0, INT_MAX],
                table: 'logs'
              }
            ],
            job_id: [
              {
                range: [0, INT_MAX],
                table: 'logs'
              }
            ]
          },
          log_parts: {
            log_id: [
              {
                range: [0, INT_MAX],
                table: 'log_parts'
              }
            ],
            active: 'log_parts'
          }
        }.freeze

        def initialize(db: nil)
          @db = db || Travis::Logs::Helpers::Database.create_sequel
        end

        attr_reader :db
        private :db

        def run
          partitions = default_mapping
          schemas = {}

          tables_strings = db.tables.sort.map(&:to_s)

          tables_strings.each do |table_name|
            schemas[table_name.to_sym] = Hash[db.schema(table_name)]
          end

          tables_strings.each do |table_name|
            partitions = populate_partition(partitions, schemas, table_name)
          end

          partitions
        end

        private def default_mapping
          JSON.parse(JSON.dump(DEFAULT_MAPPING), symbolize_names: true)
        end

        private def populate_partition(partitions, schemas, table_name)
          md = table_name.match(PARTITION_TABLE_RE)
          return partitions if md.nil?

          partition_table = md[:table].to_sym
          partitions[partition_table] ||= {}
          partitions[partition_table][:log_id] ||= []

          table_range = {
            range: populate_range(schemas[table_name.to_sym]),
            table: table_name
          }
          partitions[partition_table][:log_id] << table_range

          if partition_active?(table_range[:range], table_name)
            partitions[partition_table][:active] = table_name
          end

          partitions
        end

        private def populate_range(schema)
          id_seq = find_id_seq(schema)
          res = db[
            %(SELECT min_value, max_value FROM #{id_seq})
          ].first
          [res.fetch(:min_value), res.fetch(:max_value)]
        end

        private def partition_active?(table_range, table_name)
          max_found = db[
            %(SELECT MAX(id) FROM #{table_name})
          ].first.fetch(:max)
          return false if max_found.nil? || !max_found.positive?
          max_found > table_range.fetch(0) && max_found < table_range.fetch(1)
        end

        private def find_id_seq(schema)
          nextval = schema.fetch(:id).fetch(:default)
          nextval.match(NEXTVAL_SEQ_RE)[:seq]
        end
      end
    end
  end
end
