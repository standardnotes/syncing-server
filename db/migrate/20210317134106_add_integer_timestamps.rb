class AddIntegerTimestamps < ActiveRecord::Migration[5.2]
  def change
    add_column :items, :created_at_timestamp, :integer
    add_column :items, :updated_at_timestamp, :integer

    add_index :items, [:updated_at_timestamp], algorithm: :inplace
    add_index :items, [:user_uuid, :updated_at_timestamp, :created_at_timestamp], algorithm: :inplace
  end
end
