# frozen_string_literal: true
require 'simplecov' unless RUBY_PLATFORM =~ /^java/

ENV['PG_DISABLE_SSL'] = '1'
ENV['RACK_ENV'] = 'test'

require 'travis/logs'

Travis.logger.level = Logger::FATAL
