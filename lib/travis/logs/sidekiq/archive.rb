require 'travis'
require 'sidekiq'
require 'core_ext/hash/deep_symbolize_keys'
# require 'core_ext/module/load_constants'

Travis::Database.connect
ActiveRecord::Base.logger.level = Logger::ERROR
# Travis::Exceptions::Reporter.start
# Travis::Notification.setup

# Sidekiq::Logging.logger.formatter = ->(level, _, _, msg) do
#   "TID-#{Thread.current.object_id.to_s(36)} #{level}: #{msg}\n"
# end

Sidekiq.configure_server do |c|
  c.redis = { url: Travis.config.redis.url }
end

class Service < Travis::Logs::Services::Archive
  def log
    params[:log].content
  end

  def report(*)
    params[:log].update_attributes(archived_at: Time.now.utc, archiving: false, archive_verified: true)
  end
end

class Archiver
  include Sidekiq::Worker

  def perform(params)
    ActiveRecord::Base.silence do
      params.deep_symbolize_keys!
      Service.new(params.merge(log: Artifact.find(params[:id]))).run
    end
  end
end
