LOG_ARCHIVE_INTERVAL = 60 * 60 * 24 * 365

def unarchived_log
  sql = "archived_at IS NULL AND created_at <= NOW() - interval '? seconds'"
  Artifact::Log.where(sql, LOG_ARCHIVE_INTERVAL).order(:id).select(:id).first
end

def archive_logs
  if log = unarchived_log
    puts "queueing archive task for log: #{log.id}"
    Travis::Addons::Archive::Task.run(:archive, type: 'log', id: log.id)
  else
    puts 'DONE ARCHIVING JOBS'
    Thread.current.exit
  end
rescue Exception => e
  Travis::Exceptions.handle(e)
end
