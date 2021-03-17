class AddIntegerTimestampsIndex < ActiveRecord::Migration[5.2]
  def change
    add_index :items, [:updated_at_timestamp], algorithm: :inplace, name: 'updated_at_timestamp'
    add_index :items, [:user_uuid, :updated_at_timestamp, :created_at_timestamp], algorithm: :inplace, name: 'user_uuid_and_updated_at_timestamp_and_created_at_timestamp'
  end
end
