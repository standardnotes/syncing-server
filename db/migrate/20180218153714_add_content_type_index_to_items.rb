class AddContentTypeIndexToItems < ActiveRecord::Migration[5.0]
  def change
    # The fourth migration adds a compound index on user_uuid and contnet_type,
    # but we need one just for content_type
    add_index :items, :content_type
  end
end
