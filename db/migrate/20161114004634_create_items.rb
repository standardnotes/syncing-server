class CreateItems < ActiveRecord::Migration[5.0]
  def change
    create_table :items, id: false do |t|
      t.string :uuid, limit: 36, primary_key: true, null: false
      t.text :content
      t.string :content_type
      t.string :enc_item_key
      t.string :auth_hash
      t.string :user_uuid
      t.boolean :deleted, :default => false

      t.timestamps null: false
    end

    add_index :items, :updated_at
  end
end
