require 'simplecov' unless RUBY_PLATFORM =~ /^java/

ENV['PG_DISABLE_SSL'] = '1'

RSpec.configure do |c|
  c.before { allow($stdout).to receive(:write) }
end
