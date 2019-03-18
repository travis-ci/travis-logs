# frozen_string_literal: true

require 'coder'

require 'travis/exceptions'

module Travis
  module Logs
    class LogPartsWriter
      include Travis::Logs::MetricsMethods

      METRIKS_PREFIX = 'logs.process_log_part'

      def self.metriks_prefix
        METRIKS_PREFIX
      end

      def self.run(payload)
        new.run(payload)
      end

      def initialize(database: nil, log_parts_normalizer: nil)
        @database = database
        @log_parts_normalizer = log_parts_normalizer
      end

      private def database
        @database ||= Travis::Logs.database_connection
      end

      private def log_parts_normalizer
        @log_parts_normalizer ||=
          Travis::Logs::Services::NormalizeLogParts.new(database: database)
      end

      def run(payload)
        payload = [payload] if payload.is_a?(Hash)
        payload = Array(payload)

        measure do
          normalized = log_parts_normalizer.run(payload)

          Travis::Honeycomb.context.increment('logs.parts.count', normalized.size)
          Travis::Honeycomb.context.increment('logs.parts.bytes', normalized.map do |_, entry|
            entry['log'].bytesize
          end.reduce(&:+))

          parts = create_parts(
            normalized
          )

          # NOTE: if we have multiple payloads per batch, then we might
          #       only store the metadata for the last one in honeycomb.
          normalized.map do |_, entry|
            next unless entry['meta']

            meta = entry['meta']
            elapsed = Time.now - Time.parse(meta['queued_at'])
            Metriks.timer('logs.time_to_first_log_line.log_parts').update(elapsed)
            Metriks.timer("logs.time_to_first_log_line.infra.#{meta['infra']}.log_parts").update(elapsed)
            Metriks.timer("logs.time_to_first_log_line.queue.#{meta['queue']}.log_parts").update(elapsed)
            Travis::Honeycomb.context.sample_rate = ENV['HONEYCOMB_SAMPLE_RATE_TTFLL_LOG_PARTS']&.to_i || 1
            Travis::Honeycomb.context.merge(
              time_to_first_log_line_log_parts_ms: elapsed * 1000,
              infra: meta['infra'],
              queue: meta['queue'],
              repo:  meta['repo']
            )
          end

          parts
        end
      end

      private def create_parts(by_log_id)
        by_log_id.reject! do |log_id, entry|
          if log_id.nil? || log_id.zero?
            mark_invalid_log_id(log_id, entry)
            true
          else
            false
          end
        end
        entries = by_log_id.map do |log_id, entry|
          {
            log_id: log_id,
            number: entry['number'],
            final: final?(entry),
            content: Travis::Logs::ContentDecoder.decode_content(entry)
          }
        end
        database.create_log_parts(entries)
        by_log_id.each do |log_id, entry|
          aggregate_async(log_id, entry) if final?(entry)
        end
      rescue Sequel::Error => e
        Travis.logger.error(
          'Could not save log parts in create_parts',
          error: e.message
        )
        Travis::Exceptions.handle(e)
        raise
      end

      private def mark_invalid_log_id(log_id, entry)
        Travis.logger.warn(
          'invalid log id',
          action: 'process', job_id: entry['id'],
          result: 'invalid_id', log_id: log_id
        )
        mark('log.id_invalid')
      end

      private def aggregate_async(log_id, entry)
        Travis::Logs::Sidekiq::Aggregate.perform_in(
          intervals[:regular], log_id
        )
        Travis.logger.info(
          'scheduled async aggregation',
          job_id: entry['id'], log_id: log_id,
          in_seconds: intervals[:regular]
        )
      end

      private def final?(entry)
        !!entry['final'] # rubocop:disable Style/DoubleNegation
      end

      private def intervals
        Travis.config.logs.intervals
      end
    end
  end
end
