require "bundler/setup"
require "rake"

$LOAD_PATH << File.expand_path("../lib", __FILE__)
require "travis/logs"
require "travis/support"
require "travis/logs/helpers/database"

namespace :db do
  task :setup do
    db = Travis::Logs::Helpers::Database.create_sequel
    db.create_table(:logs) do
      primary_key :id
      Integer :job_id
      String :content, text: true
      DateTime :created_at
      DateTime :updated_at
      DateTime :aggregated_at
      FalseClass :archiving
      DateTime :archived_at
      FalseClass :archive_verified
      DateTime :purged_at

      index :archive_verified, name: "index_logs_on_archive_verified"
      index :archived_at, name: "index_logs_on_archived_at"
      index :job_id, name: "index_logs_on_job_id"
    end

    db.create_table(:log_parts) do
      primary_key :id
      Integer :log_id, null: false
      String :content, text: true
      Integer :number
      FalseClass :final
      DateTime :created_at

      index [:log_id, :number], name: "index_log_parts_on_log_id_and_number"
    end
  end

  task :drop do
    db = Travis::Logs::Helpers::Database.create_sequel
    db.drop_table(:logs)
    db.drop_table(:log_parts)
  end
end
