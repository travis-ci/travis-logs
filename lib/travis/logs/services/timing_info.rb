# frozen_string_literal: true

require 'concurrent'
require 'date'
require 'travis/logs'

module Travis
  module Logs
    module Services
      class TimingInfo
        attr_reader :job_id, :database

        private :database

        TIMER_START = /travis_time:start:(?<timer_id>[0-9a-f]+)/
        TIMER_END = /travis_time:end:(?<timer_id>[0-9a-f]+):(?<info>[^\r]+)\r/

        def self.run
          new.run
        end

        def self.timing_info(job_id)
          new.timing_info(job_id)
        end

        def initialize(job_id, database: Travis::Logs.database_connection)
          @job_id   = job_id
          @database = database
        end

        def run
          timing_info job_id
        end

        def timing_info(job_id)
          timer_stack = []
          # Build a honeycomb event
          honey = Travis::Honeycomb.honey

          ev_builder = honey.builder
          ev_builder.writekey = Travis.config.logs.honeycomb.build_timings.writekey
          ev_builder.dataset  = Travis.config.logs.honeycomb.build_timings.dataset

          content.each_line do |l|
            l.scan(/#{TIMER_START}|#{TIMER_END}/) do |start_timer_id, end_timer_id, info|
              if start_timer_id
                timer_stack << start_timer_id
                next
              end

              if timer_stack.empty?
                Travis.logger.debug "Empty log event timer stack"
                next
              end
              unless (last_timer_id = timer_stack.pop) == end_timer_id
                Travis.logger.debug "Timer IDs do not match. From stack: #{last_timer_id}; seen: #{end_timer_id}"
                next
              end

              # matched TIMER_END regexp, so we have `end_timer_id` and `info` defined
              marker_data = parse_marker_data(info)
              next unless extra_info?(marker_data)

              event = ev_builder.event
              event.timestamp = Time.at(marker_data[:finish].to_i / 10**9)
              event.add_field(:job_id, job_id)
              event.add normalize_timestamps(marker_data)

              event.send
              Travis.logger.debug event.to_s
            end
          end
        end

        def log
          @log ||= begin
            log_id = database.log_id_for_job_id(job_id)
            log = database.log_for_id(log_id)
            unless log
              Travis.logger.warn(
                'log not found',
                action: 'timing_info', id: log_id, result: 'not_found'
              )
            end
            log
          end
        end

        private

        def content
          @content ||= log.fetch(:content, '')
        end

        attr_writer :content
        private :content

        def parse_marker_data(str)
          # given a comma-delimited string with each being an equal-delimited
          # key-value paris, build a hash with the key-value pairs thus specified
          # with symbols as keys
          # e.g., 'a=b,c=d' => '{:a=>"b", :c=> "d"}'
          str.split(',')
             .select { |s| s.include?('=') }
             .map    { |s| s.split('=', 2) }
             .to_h
             .transform_keys(&:to_sym)
        end

        def normalize_timestamps(hsh)
          hsh.each_with_object({}) do |pair, memo|
            k, v = pair
            case k
            when :start, :finish
              # nanoseconds to seconds
              memo[k] = v.to_i / (10**9)
            when :duration
              # nanoseconds to milliseconds
              memo[:duration_ms] = v.to_i / (10**6)
            else
              memo[k] = v
            end
            memo
          end
        end

        def extra_info?(hsh)
          base_keys = %i[start finish duration]
          !hsh.reject { |k, _| base_keys.include?(k) }.empty?
        end
      end
    end
  end
end
