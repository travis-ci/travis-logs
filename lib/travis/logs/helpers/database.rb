require 'travis/support/database'
require 'travis/logs/models'

module Travis
  module Logs
    module Helpers
      module Database

        # the only way to preload the columns for AR is to call [model].columns
        def self.setup
          Travis.logger.info('Setting up database connection and preloading model columns')
          Travis::Database.connect
          Log.columns
          LogPart.columns
        end

      end
    end
  end
end