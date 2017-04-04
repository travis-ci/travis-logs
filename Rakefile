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
    sh 'sqitch deploy'
    sh 'sqitch verify'
  end
end

desc 'Set up test bits'
task setup: :'db:test-setup'

task default: %i(rubocop spec)
