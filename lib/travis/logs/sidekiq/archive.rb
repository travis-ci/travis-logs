# Do not use. This was used to archive the backlog of logs.
# For day to day archiving travis-tasks should be used.

require 'travis'
require 'sidekiq'
require 'core_ext/hash/deep_symbolize_keys'

Travis::Database.connect
ActiveRecord::Base.logger.level = Logger::ERROR
Travis::Notification.setup

Sidekiq.configure_server do |c|
  c.redis = { url: Travis.config.redis.url }
end

class Service < Travis::Logs::Services::Archive
  def log
    params[:log].content
  end

  def report(*)
    params[:log].update_attributes!(archived_at: Time.now.utc, archiving: false, archive_verified: true)
  end
end

class Archiver
  include Sidekiq::Worker

  def perform(params)
    ActiveRecord::Base.silence do
      params.deep_symbolize_keys!
      puts "archiving: #{params.inspect}"
      Service.new(params.merge(log: Log.find(params[:id]))).run
    end
  rescue Exception => e
    puts e.message, e.backtrace
    raise
  end
end
