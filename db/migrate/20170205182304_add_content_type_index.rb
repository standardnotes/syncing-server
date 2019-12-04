class AddContentTypeIndex < ActiveRecord::Migration[5.0]
  def change
    add_index :items, :user_uuid
    add_index :items, [:user_uuid, :content_type]
  end
end
