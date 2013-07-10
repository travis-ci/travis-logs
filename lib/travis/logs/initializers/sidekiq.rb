$: << 'lib'

require 'travis/logs'
require 'travis/support'
require 'travis/support/exceptions/reporter'
require 'travis/logs/helpers/database'
require 'travis/logs/helpers/reporting'
require 'active_support/core_ext/logger'
require 'travis/logs/sidekiq'
require 'core_ext/hash/deep_symbolize_keys'

$stdout.sync = true
Travis.logger.info('** Setting up Sidekiq **')

Travis::Logs::Helpers::Reporting.setup
Travis::Exceptions::Reporter.start

Travis::Logs.database_connection = Travis::Logs::Helpers::Database.connect

Travis::Logs::Sidekiq.setup

# load the workers
require 'travis/logs/sidekiq/archive'