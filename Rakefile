begin
  require 'rspec/core/rake_task'
  require 'rubocop/rake_task'
rescue LoadError => e
  warn e
end

RSpec::Core::RakeTask.new if defined?(RSpec)
RuboCop::RakeTask.new if defined?(RuboCop)

task :databass do
  sh 'createdb travis_logs_test'
  sh './script/cat-structure-sql | psql -q travis_logs_test'
end

desc 'Set up test bits'
task setup: :databass

task default: %i(rubocop spec)
