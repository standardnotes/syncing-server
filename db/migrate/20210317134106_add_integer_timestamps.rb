class AddIntegerTimestamps < ActiveRecord::Migration[5.2]
  def change
    add_column :items, :created_at_timestamp, :integer
    add_column :items, :updated_at_timestamp, :integer
  end
end
