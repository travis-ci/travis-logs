# frozen_string_literal: true
source 'https://rubygems.org'

ruby '2.3.1', engine: 'jruby', engine_version: '9.1.5.0' if ENV.key?('DYNO')

def gh(slug)
  "https://github.com/#{slug}.git"
end

gem 'activesupport', '~> 3'
gem 'aws-sdk'
gem 'bunny', platform: :mri
gem 'coder', git: gh('rkh/coder')
gem 'concurrent-ruby', require: 'concurrent'
gem 'connection_pool'
gem 'excon'
gem 'faraday'
gem 'jdbc-postgres', platform: :jruby
gem 'jrjackson', platform: :jruby
gem 'jruby-openssl', platform: :jruby
gem 'json'
gem 'jwt'
gem 'march_hare', '~> 2', platform: :jruby
gem 'metriks'
gem 'metriks-librato_metrics'
gem 'oj', platform: :mri
gem 'pg', platform: :mri
gem 'pry'
gem 'puma'
gem 'pusher', '~> 0.14'
gem 'rack-ssl'
gem 'rack-test', group: :test
gem 'rake'
gem 'redis-namespace'
gem 'redlock'
gem 'rspec', group: :test
gem 'rubocop', require: false, group: :test
gem 'sentry-raven', git: gh('getsentry/raven-ruby')
gem 'sequel'
gem 'sidekiq'
gem 'simplecov', require: false, group: :test
gem 'sinatra', '~> 1'
gem 'sinatra-contrib'
gem 'sinatra-param'
gem 'travis-amqp', git: gh('travis-ci/travis-amqp')
gem 'travis-config', '~> 1.0'
gem 'travis-lock', git: 'https://github.com/travis-ci/travis-lock.git'
gem 'travis-migrations', git: gh('travis-ci/travis-migrations'), group: :test
gem 'travis-support', git: gh('travis-ci/travis-support')
