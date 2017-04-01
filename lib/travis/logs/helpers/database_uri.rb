# frozen_string_literal: true

require 'uri'

module Travis
  module Logs
    module Helpers
      class DatabaseURI
        class << self
          def uri_from_config(config)
            host = config[:host] || 'localhost'
            port = config[:port] || 5432
            database = config[:database]
            username = config[:username] || ENV['USER']

            params = {
              user: username,
              password: config[:password]
            }

            enc_params = URI.encode_www_form(params)
            "postgres://#{host}:#{port}/#{database}?#{enc_params}"
          end

          def jdbc_uri_from_config(config)
            host = config[:host] || 'localhost'
            port = config[:port] || 5432
            database = config[:database]
            username = config[:username] || ENV['USER']

            params = {
              user: username,
              password: config[:password]
            }

            if config[:ssl]
              params[:ssl] = true
              params[:sslfactory] = 'org.postgresql.ssl.NonValidatingFactory'
            end

            enc_params = URI.encode_www_form(params)
            "jdbc:postgresql://#{host}:#{port}/#{database}?#{enc_params}"
          end
        end
      end
    end
  end
end
