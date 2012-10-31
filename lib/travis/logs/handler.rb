module Travis
  class Logs
    class  Handler
      autoload :Log,   'travis/logs/handler/log'
      autoload :Route, 'travis/logs/handler/route'

      class << self
        def handle(type, payload)
          payload = { 'data' => payload } unless payload.key?('data') # TODO happens when message comes directly from the worker
          handler(type).new(payload).handle
        end

        def handler(type)
          const_get(type.to_s.camelize)
        end
      end

      include Logging
      extend  Instrumentation, NewRelic

      attr_accessor :payload

      def initialize(payload)
        @payload = payload
      end
    end
  end
end

