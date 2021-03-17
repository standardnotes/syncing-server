class AddIntegerTimestamps < ActiveRecord::Migration[5.2]
  def change
    add_column :items, :created_at_timestamp, :bigint
    add_column :items, :updated_at_timestamp, :bigint
  end
end
