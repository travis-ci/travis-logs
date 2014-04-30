source 'https://rubygems.org'

ruby '1.9.3', engine: 'jruby', engine_version: '1.7.6' unless ENV["TRAVIS"]

gem 'activesupport'
gem 'travis-support',     github: 'travis-ci/travis-support'

gem 'sequel',             '~> 4.0.0'
gem 'jdbc-postgres',      '~> 9.2.1002.1'

gem 'march_hare',         '~> 2.0.0.rc1'
gem 'jruby-openssl',      '~> 0.8.8'

gem 'json',               '~> 1.8.0'
gem 'hashr'
gem 'pusher',             '~> 0.11.3'
gem 'metriks',            '~> 0.9.9.4'
gem 'coder',              github: 'rkh/coder' # '~> 0.3.0'
gem 'sidekiq'
gem 'aws-sdk'
gem 'faraday',            '~> 0.8.8'
gem 'sentry-raven',       github: 'getsentry/raven-ruby'

gem 'rake'

group :test do
  gem 'rspec',            '~> 2.14.1'
end
