class AddBetterIndexes < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!
  def change
    add_index :items, [:user_uuid, :updated_at, :created_at], algorithm: :inplace
  end
end
