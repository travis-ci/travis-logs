require 'travis/logs'
require 'active_support/core_ext/string'

require 'travis/logs/helpers/s3'
require 'travis/logs/helpers/file_storage'

module Travis
  module Logs
    module Helpers
      class LogStorageProvider
        def self.provider
          provider_class_name = Travis::Logs.config.log_storage_provider.camelize;
          ("Travis::Logs::Helpers::" + provider_class_name).constantize
        end
      end
    end
  end
end
