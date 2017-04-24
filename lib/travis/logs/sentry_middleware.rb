# frozen_string_literal: true

require 'raven'
require 'sinatra/base'

module Travis
  module Logs
    class SentryMiddleware < Sinatra::Base
      configure do
        Raven.configure { |c| c.tags = { environment: environment } }
        use Raven::Rack
      end
    end
  end
end
