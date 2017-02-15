require 'travis/lock'

module Travis
  module Logs
    module Helpers
      module Locking
        def exclusive(key, options = nil, &block)
          options ||= Travis.config.lock.to_h
          options[:url] ||= Travis.config.redis.url if options[:strategy] == :redis

          logger.debug "Locking #{key} with: #{options[:strategy]}, ttl: #{options[:ttl]}"
          Lock.exclusive(key, options, &block)
        end

        def logger
          Travis.logger
        end
      end
    end
  end
end
