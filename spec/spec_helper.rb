ENV['RAILS_ENV'] ||= 'test'

require 'travis'
require 'stringio'
require 'mocha'
require 'active_record'
require 'logger'

ActiveRecord::Base.class_eval do
  def self.inspect
    super
  end
end

Travis.logger = Logger.new(StringIO.new)

include Mocha::API

RSpec.configure do |c|
  c.mock_with :mocha

  c.after :each do
    Travis.config.notifications.clear
  end
end

