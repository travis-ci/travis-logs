# frozen_string_literal: true

begin
  require 'rspec/core/rake_task'
  require 'rubocop/rake_task'
rescue LoadError => e
  warn e
end

RSpec::Core::RakeTask.new if defined?(RSpec)
RuboCop::RakeTask.new if defined?(RuboCop)

namespace :db do
  task :'test-setup' do
    sh 'createdb travis_logs_test'
    sh './script/cat-structure-sql | psql -q travis_logs_test'
  end

  desc 'Set table-level autovacuum and database-level vacuum settings'
  task :'vacuum-settings' do
    libdir = File.expand_path('../lib', __FILE__)
    $LOAD_PATH.unshift(libdir) unless $LOAD_PATH.include?(libdir)
    require 'travis/logs'
    require 'travis/logs/helpers/database'
    Travis::Logs::Helpers::Database.vacuum_settings
    Travis.logger.info('all done')
  end
end

desc 'Set up test bits'
task setup: :'db:test-setup'

task default: %i(rubocop spec)
