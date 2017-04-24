# frozen_string_literal: true

require 'simplecov'

ENV['RACK_ENV'] = 'test'

require 'travis/logs'

Travis.logger.level = Logger::FATAL
