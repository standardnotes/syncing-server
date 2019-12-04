class ChangeItemKeyToText < ActiveRecord::Migration[5.0]
  def change
    change_column :items, :enc_item_key, :text
  end
end
