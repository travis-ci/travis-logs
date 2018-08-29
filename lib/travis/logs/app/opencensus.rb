# frozen_string_literal: true
require 'opencensus'
require 'opencensus/stackdriver'

module Travis
  class Logs
    class OpenCensus
      module Sequel
        def log_connection_yield(sql, conn, args=nil)
          OpenCensus::Trace.in_span "sql" do |span|
            span.put_attribute "sql", sql
            super
          end
        end
      end

      ##
      # List of trace context formatters we use to parse the parent span
      # context.
      #
      # @private
      #
      AUTODETECTABLE_FORMATTERS = [
        ::OpenCensus::Trace::Formatters::CloudTrace.new,
        ::OpenCensus::Trace::Formatters::TraceContext.new
      ].freeze

      ##
      # Create the middleware.
      #
      # @param [#call] app Next item on the middleware stack
      # @param [#export] exporter The exported used to export captured spans
      #     at the end of the request. Optional: If omitted, uses the exporter
      #     in the current config.
      def initialize app, exporter: nil
        @app = app
        @exporter = exporter || ::OpenCensus::Trace.config.exporter
      end

      def self.enabled?
        ENV['OPENCENSUS_TRACING_ENABLED'] == 'true'
      end

      def self.setup
        return unless enabled?

        sampling_rate = ENV['OPENCENSUS_SAMPLING_RATE']&.to_f || 1
        ::OpenCensus.configure do |c|
          c.trace.exporter = ::OpenCensus::Trace::Exporters::Stackdriver.new
          c.trace.default_sampler = ::OpenCensus::Trace::Samplers::Probability.new sampling_rate
          c.trace.default_max_attributes = 16
        end

        setup_notifications
      end

      def self.setup_notifications
        Database.register_extension(:opencensus, Travis::Logs::OpenCensus::Sequel)
      end

      ##
      # Run the middleware.
      #
      # @param [Hash] env The rack environment
      # @return [Array] The rack response. An array with 3 elements: the HTTP
      #     response code, a Hash of the response headers, and the response
      #     body which must respond to `each`.
      #
      def call env
        formatter = AUTODETECTABLE_FORMATTERS.detect do |f|
          env.key? f.rack_header_name
        end
        if formatter
          context = formatter.deserialize env[formatter.rack_header_name]
        end

        ::OpenCensus::Trace.start_request_trace \
        trace_context: context,
        same_process_as_parent: false do |span_context|
          begin
            span_context.in_span get_path(env) do |span|
              start_request span, env
              @app.call(env).tap do |response|
                finish_request span, response
              end
            end
          ensure
            @exporter.export span_context.build_contained_spans
          end
        end
      end

      private

      def get_path env
        path = "#{env['SCRIPT_NAME']}#{env['PATH_INFO']}"
        path = "/#{path}" unless path.start_with? "/"
        path
      end

      def get_host env
        env["HTTP_HOST"] || env["SERVER_NAME"]
      end

      def get_url env
        path = get_path env
        host = get_host env
        scheme = env["rack.url_scheme"]
        query_string = env["QUERY_STRING"].to_s
        url = "#{scheme}://#{host}#{path}"
        url = "#{url}?#{query_string}" unless query_string.empty?
        url
      end

      def start_request span, env
        span.kind = ::OpenCensus::Trace::SpanBuilder::SERVER
        span.put_attribute "app", "logs"
        span.put_attribute "site", ENV["TRAVIS_SITE"]
        span.put_attribute "request_id", env["HTTP_X_REQUEST_ID"]
        span.put_attribute "http/host", get_host(env)
        span.put_attribute "http/url", get_url(env)
        span.put_attribute "http/method", env["REQUEST_METHOD"]
        span.put_attribute "http/client_protocol", env["SERVER_PROTOCOL"]
        span.put_attribute "http/user_agent", env["HTTP_USER_AGENT"]
        span.put_attribute "pid", ::Process.pid.to_s
        span.put_attribute "tid", ::Thread.current.object_id.to_s
      end

      def finish_request span, response
        if response.is_a?(::Array) && response.size == 3
          span.set_status response[0]
        end
      end
    end
  end
end
