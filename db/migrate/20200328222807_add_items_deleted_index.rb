class AddItemsDeletedIndex < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!
  def change
    add_index :items, [:deleted], algorithm: :inplace
  end
end
