source 'https://rubygems.org'

ruby '1.9.3', engine: 'jruby', engine_version: '1.7.16' if ENV.key?('DYNO')

gem 'activesupport',      '~> 3.2'
gem 'travis-support',     github: 'travis-ci/travis-support'
gem 'travis-config',      '~> 0.1.0'

gem 'sequel',             '~> 4.0.0'
gem 'jdbc-postgres',      '9.3.1101'

gem 'march_hare',         '~> 2.3.0'
gem 'jruby-openssl',      '~> 0.8.8'

gem 'json',               '~> 1.8.0'
gem 'pusher',             '~> 0.12.0'
gem 'metriks'
gem 'metriks-librato_metrics'
gem 'coder',              github: 'rkh/coder' # '~> 0.3.0'
gem 'sidekiq'
gem 'aws-sdk'
gem 'faraday',            '~> 0.8.8'
gem 'sentry-raven',       github: 'getsentry/raven-ruby'

gem 'rails_12factor'

gem 'rake'

group :test do
  gem 'rspec',            '~> 2.14.1'
  gem 'rack-test'
end

gem 'sinatra', '~> 1.4'
gem 'puma'
gem 'rack-ssl'
gem 'connection_pool'
