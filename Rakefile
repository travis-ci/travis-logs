# frozen_string_literal: true

begin
  require 'rspec/core/rake_task'
  require 'rubocop/rake_task'
rescue LoadError => e
  warn e
end

RSpec::Core::RakeTask.new if defined?(RSpec)
RuboCop::RakeTask.new if defined?(RuboCop)

task :'db:create' do
  sh 'createdb travis_logs_test'
end

task :'db:migrate' do
  sh 'sqitch deploy'
  sh 'sqitch verify'
end

desc 'Set up test bits'
task setup: %i[db:create db:migrate]

task default: %i[rubocop spec]
