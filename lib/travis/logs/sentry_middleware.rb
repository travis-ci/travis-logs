# frozen_string_literal: true

require 'raven'
require 'sinatra/base'

module Travis
  module Logs
    class SentryMiddleware < Sinatra::Base
      configure do
        use Raven::Rack
      end
    end
  end
end
