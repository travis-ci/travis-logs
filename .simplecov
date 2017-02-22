SimpleCov.start do
  add_filter 'spec/'
  add_filter 'initializers/'
end if ENV['COVERAGE']
