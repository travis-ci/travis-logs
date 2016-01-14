Sequel.migration do
  change do
    create_table(:logs) do
      primary_key :id
      integer :job_id
      text :content

      timestamp :created_at
      timestamp :updated_at

      timestamp :aggregated_at
      timestamp :archived_at
      timestamp :purged_at

      boolean :archiving
      boolean :archive_verified

      index :archive_verified, name: 'index_logs_on_archive_verified'
      index :archived_at, name: 'index_logs_on_archived_at'
      index :job_id, name: 'index_logs_on_job_id'
    end
  end
end
