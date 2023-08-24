# frozen_string_literal: true

source 'https://rubygems.org'

ruby '2.5.8' if ENV.key?('DYNO')

def gh(slug)
  "https://github.com/#{slug}.git"
end

gem 'activesupport', '>= 7.0.7.1'
gem 'aws-sdk'
gem 'bunny'
gem 'coder'
gem 'concurrent-ruby', require: 'concurrent'
gem 'connection_pool'
gem 'dalli', '>= 3.2.3'
gem 'jemalloc', git: gh('joshk/jemalloc-rb')
gem 'jwt'
gem 'libhoney'
gem 'metriks', git: gh('travis-ci/metriks')
gem 'metriks-librato_metrics', git: gh('travis-ci/metriks-librato_metrics')
gem 'multi_json'
gem 'opencensus'
gem 'opencensus-stackdriver', '>= 0.3.0'
gem 'pg'
gem 'pry'
gem 'puma', '>= 6.3.1'
gem 'pusher'
gem 'rack-ssl'
gem 'rack-test', '>= 2.0.0', group: :test
gem 'rake'
gem 'rbtrace'
gem 'redis-namespace'
gem 'redlock'
gem 'rspec', group: :test
gem 'rubocop', require: false, group: :test
gem 'sentry-raven'
gem 'sequel'
gem 'sidekiq', '>= 7.0.8'
gem 'simplecov', require: false, group: :test
gem 'sinatra', '>= 2.2.3'
gem 'sinatra-contrib', '>= 2.2.3'
gem 'sinatra-param'
gem 'stackprof'
gem 'travis-config'
gem 'travis-exceptions', git: gh('travis-ci/travis-exceptions')
gem 'travis-lock', git: gh('travis-ci/travis-lock')
gem 'travis-logger', git: gh('travis-ci/travis-logger')
gem 'travis-metrics', git: gh('travis-ci/travis-metrics')
