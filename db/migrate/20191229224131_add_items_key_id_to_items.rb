class AddItemsKeyIdToItems < ActiveRecord::Migration[5.1]
  def change
    add_column :items, :items_key_id, :string, :after => :uuid
  end
end