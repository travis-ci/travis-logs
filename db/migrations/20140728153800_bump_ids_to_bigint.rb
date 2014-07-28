Sequel.migration do
  change do
    alter_table(:log_parts) do
      set_column_type :id, Bignum
    end
  end
end
