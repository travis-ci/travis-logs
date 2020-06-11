# frozen_string_literal: true

source 'https://rubygems.org'

ruby '2.5.8' if ENV.key?('DYNO')

def gh(slug)
  "https://github.com/#{slug}.git"
end

gem 'activesupport'
gem 'aws-sdk'
gem 'bunny'
gem 'coder'
gem 'concurrent-ruby', require: 'concurrent'
gem 'connection_pool'
gem 'dalli'
gem 'jemalloc', git: gh('joshk/jemalloc-rb')
gem 'jwt'
gem 'libhoney'
gem 'metriks', git: gh('travis-ci/metriks')
gem 'metriks-librato_metrics', git: gh('travis-ci/metriks-librato_metrics')
gem 'multi_json'
gem 'opencensus'
gem 'opencensus-stackdriver'
gem 'pg'
gem 'pry'
gem 'puma'
gem 'pusher'
gem 'rack-ssl'
gem 'rack-test', group: :test
gem 'rake'
gem 'rbtrace'
gem 'redis-namespace'
gem 'redlock'
gem 'rspec', group: :test
gem 'rubocop', require: false, group: :test
gem 'sentry-raven'
gem 'sequel'
gem 'sidekiq'
gem 'simplecov', require: false, group: :test
gem 'sinatra'
gem 'sinatra-contrib'
gem 'sinatra-param'
gem 'stackprof'
gem 'travis-config'
gem 'travis-exceptions', git: gh('travis-ci/travis-exceptions')
gem 'travis-lock', git: gh('travis-ci/travis-lock')
gem 'travis-logger', git: gh('travis-ci/travis-logger')
gem 'travis-metrics', git: gh('travis-ci/travis-metrics')
