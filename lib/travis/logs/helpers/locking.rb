require 'travis/lock'

module Travis
  module Logs
    module Helpers
      module Locking
        def exclusive(key, options = nil, &block)
          options ||= config.lock.to_h
          options[:url] ||= config.redis.url if options[:strategy] == :redis

          logger.debug "Locking #{key} with: #{options[:strategy]}, ttl: #{options[:ttl]}"
          Lock.exclusive(key, options, &block)
        end

        def logger
          Scheduler.logger
        end
      end
    end
  end
end
