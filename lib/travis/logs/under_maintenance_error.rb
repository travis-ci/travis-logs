# frozen_string_literal: true

module Travis
  module Logs
    class UnderMaintenanceError < StandardError
      def initialize(ttl)
        @ttl = ttl
      end

      attr_reader :ttl

      def http_status
        503
      end

      def message
        "under maintenance for the next #{ttl}s"
      end
    end
  end
end
