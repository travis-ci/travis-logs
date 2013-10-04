require 'hashr'
require 'yaml'

require 'active_support/core_ext/object/blank'
require 'core_ext/hash/deep_symbolize_keys'

require 'travis/support/logging'

require 'pusher'

# Encapsulates the configuration necessary for travis-core.
#
# Configuration values will be read from
#
#  * either ENV['travis_config'] (this variable is set on Heroku by `travis config [env]`,
#    see travis-cli) or
#  * a local file config/travis.yml which contains the current env key (e.g. development,
#    production, test)
#
# The env key can be set through various ENV variables, see Travis::Config.env.
#
# On top of that the database configuration can be overloaded by setting a database URL
# to ENV['DATABASE_URL'] or ENV['SHARED_DATABASE_URL'] (which is something Heroku does).
module Travis
  module Logs
    class Config < Hashr
      class << self
        def env
          ENV['ENV'] || ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development'
        end

        def load_env
          @load_env ||= YAML.load(ENV['travis_config']) if ENV['travis_config']
        end

        def load_file
          @load_file ||= YAML.load_file(filename)[Travis.env] if File.exists?(filename) rescue {}
        end

        def filename
          @filename ||= File.expand_path('config/travis.yml')
        end

        def database_env_url
          ENV.values_at('DATABASE_URL', 'SHARED_DATABASE_URL').first
        end

        def database_from_env
          url = database_env_url
          url ? parse_database_url(url) : {}
        end

        def parse_database_url(url)
          if url =~ %r((.+?)://(.+):(.+)@([^:]+):?(.*)/(.+))
            database = $~.to_a.last
            adapter, username, password, host, port = $~.to_a[1..-2]
            adapter = 'postgresql' if adapter == 'postgres'
            { :adapter => adapter, :username => username, :password => password, :host => host, :database => database }.tap do |config|
              config.merge!(:port => port) unless port.blank?
            end
          else
            {}
          end
        end

        def normalize(data)
          data.deep_symbolize_keys!
          if database_from_env
            data[:database] ||= {}
            data[:database].merge! database_from_env do |key, old_value, new_value|
              if old_value == new_value
                old_value
              else
                fail "Conflict in database config between ENV and travis.yml: #{key} is #{old_value.inspect} vs #{new_value}"
              end
            end
          end
          data
        end
      end

      include Logging

      define  :amqp          => { :username => 'guest', :password => 'guest', :host => 'localhost', :prefetch => 1 },
              :database      => { :adapter => 'postgresql', :database => "travis_#{env}", :encoding => 'unicode', :min_messages => 'warning' },
              :s3            => { :hostname => "archive.travis-ci.org", :access_key_id => '', :secret_access_key => '', :acl => :public_read },
              :pusher        => { :app_id => 'app-id', :key => 'key', :secret => 'secret', :secure => false },
              :sidekiq       => { :namespace => 'sidekiq', :pool_size => 3 },
              :logs          => { :archive => true, :threads => 10, :intervals => { :vacuum => 10, :regular => 180, :force => 3 * 60 * 60 } },
              :redis         => { :url => 'redis://localhost:6379' },
              :ssl           => { },
              :sentry        => { }

      default :_access => [:key]

      def initialize(data = nil, *args)
        data = self.class.normalize(data || self.class.load_env || self.class.load_file || {})
        super
      end

      def env
        self.class.env
      end

      def pusher_client
        @pusher ||= ::Pusher::Client.new(self.pusher)
      end
    end
  end
end