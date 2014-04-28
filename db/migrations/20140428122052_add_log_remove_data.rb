Sequel.migration do
  alter_table(:logs) do
    add_column :removed_by, :integer
    add_column :removed_at, :timestamp
  end
end
