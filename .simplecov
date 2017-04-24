SimpleCov.start do
  add_filter 'spec/'
  add_filter 'sidekiq/initializer.rb'
  minimum_coverage 80
end if ENV['COVERAGE']
