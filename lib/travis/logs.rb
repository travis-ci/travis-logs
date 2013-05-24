require 'travis/logs/config'

module Travis
  def self.config
    Logs.config
  end

  module Logs
    def self.config
      @config ||= Config.new
    end
  end
end