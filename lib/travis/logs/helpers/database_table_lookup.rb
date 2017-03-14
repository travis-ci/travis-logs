# frozen_string_literal: true
require 'json'

module Travis
  module Logs
    module Helpers
      class DatabaseTableLookup
        def initialize(mapping: nil)
          @map = normalize_mapping(
            mapping.nil? || mapping.empty? ? {} : mapping
          )
        end

        attr_reader :map
        private :map

        def logs_table_for_log_id(log_id)
          find_between(map.fetch(:logs).fetch(:log_id), log_id)
        end

        def logs_table_for_job_id(job_id)
          find_between(map.fetch(:logs).fetch(:job_id), job_id)
        end

        def logs_tables
          map.fetch(:logs).map do |_, v|
            v.map { |h| h.fetch(:table) }
          end.flatten.compact.uniq.map(&:to_sym)
        end

        def log_parts_tables
          map.fetch(:log_parts).map do |k, v|
            next if k == :active
            v.map { |h| h.fetch(:table) }
          end.flatten.compact.uniq.map(&:to_sym)
        end

        def log_parts_table_for_log_id(log_id)
          find_between(map.fetch(:log_parts).fetch(:log_id), log_id)
        end

        def active_log_parts_table
          map.fetch(:log_parts).fetch(:active).to_sym
        end

        private def normalize_mapping(abnormal_mapping)
          JSON.parse(
            JSON.dump(abnormal_mapping),
            symbolize_names: true
          )
        end

        private def find_between(lookup, id)
          lookup.find do |h|
            id.between?(
              h.fetch(:range).fetch(0),
              h.fetch(:range).fetch(1)
            )
          end.fetch(:table).to_sym
        end
      end
    end
  end
end
