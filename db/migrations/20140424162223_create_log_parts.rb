Sequel.migration do
  change do
    create_table(:log_parts) do
      primary_key :id
      integer :log_id, null: false
      text :content
      integer :number
      boolean :final
      timestamp :created_at

      index [:log_id, :number], name: 'index_log_parts_on_log_id_and_number'
    end
  end
end
