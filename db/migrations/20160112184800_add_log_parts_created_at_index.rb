Sequel.migration do
  no_transaction

  change do
    alter_table(:log_parts) do
      add_index :created_at, concurrently: true
    end
  end
end
