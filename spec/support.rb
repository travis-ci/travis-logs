require 'simplecov'

require 'travis/logs'
require 'travis/logs/helpers/metrics'

Travis.config.log_level = :fatal

ENV['PG_DISABLE_SSL'] = '1'
