Sequel.migration do
  change do
    alter_table(:logs) do
      add_column :removed_by_id, :integer
    end
  end
end
