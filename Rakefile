begin
  require 'rspec/core/rake_task'
  require 'rubocop/rake_task'
rescue LoadError => e
  warn e
end

RSpec::Core::RakeTask.new if defined?(RSpec)
RuboCop::RakeTask.new if defined?(RuboCop)

file 'config/travis.yml' do |t|
  cp 'config/travis.example.yml', t.name
end

def psql(statement)
  %(psql travis_logs_test -c "#{statement}" &>/dev/null)
end

namespace :test do
  desc 'Set up test bits'
  task setup: %w(config/travis.yml load_structure)

  desc 'Create test database'
  task :createdb do
    sh psql('select now()') do |ok, _|
      sh 'createdb travis_logs_test' unless ok
    end
  end

  desc 'Load database structure from travis-migrations'
  task load_structure: :createdb do
    sh psql('select max(id) from logs') do |ok, _|
      sh './script/cat-structure-sql | psql -q travis_logs_test' unless ok
    end
  end
end

task default: %i(test:setup rubocop spec)
