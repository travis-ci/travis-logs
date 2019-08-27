# frozen_string_literal: true

require 'concurrent'
require 'date'
require 'travis/logs'

module Travis
  module Logs
    module Services
      class SendTimings
        attr_reader :job_id, :database

        private :database

        TIMER_START = /travis_time:start:(?<timer_id>[0-9a-f]+)/
        TIMER_END = /travis_time:end:(?<timer_id>[0-9a-f]+):(?<info>[^\r]+)\r/

        def self.run
          new.run
        end

        def self.send_timings(job_id)
          new.send_timings(job_id)
        end

        def initialize(job_id, database: Travis::Logs.database_connection)
          @job_id   = job_id
          @database = database
        end

        def run
          send_timings job_id
        end

        def send_timings(job_id)
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
                next
              end
              unless (last_timer_id = timer_stack.pop) == end_timer_id
                next
              end

              # matched TIMER_END regexp, so we have `end_timer_id` and `info` defined
              marker_data = parse_marker_data(info)

              event = ev_builder.event
              event.add_field(:job_id, job_id)
              event.add normalize_timestamps(marker_data)

              event.send
              Travis.logger.info event.to_s
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
                action: 'send_timings', id: log_id, result: 'not_found'
              )
            end
            log
          end
        end
        alias fetch log

        private

        def content
          @content ||= log[:content]
        end

        attr_writer :content
        private :content

        def parse_marker_data(str)
          # given a comma-delimited string with each being an equal-delimited
          # key-value paris, build a hash with the key-value pairs thus specified
          # with symbols as keys
          # e.g., 'a=b,c=d' => '{:a=>"b", :c=> "d"}'
          str.split(',').map { |s| s.split('=', 2) }.to_h.transform_keys(&:to_sym)
        end

        def normalize_timestamps(hsh)
          new_hsh = {}

          hsh.each do |k,v|
            case k
            when :start, :finish
              # nanoseconds to seconds
              new_hsh[k] = v.to_i / (10**9)
            when :druation
              # nanoseconds to milliseconds
              new_hsh[:duration_ms] = v.to_i / (10**6)
            else
              new_hsh[k] = v
            end
          end

          new_hsh
        end
      end
    end
  end
end
