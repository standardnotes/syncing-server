class AddItemRevisions < ActiveRecord::Migration[5.1]
  def change
    create_table "item_revisions", id: false do |t|
      t.string "uuid", limit: 36, primary_key: true, null: false
      t.string "item_uuid", limit: 36, null: false
      t.string "revision_uuid", limit: 36, null: false
      t.index ["item_uuid"]
      t.index ["revision_uuid"]
    end

    create_table "revisions", id: false do |t|
      t.string "uuid", limit: 36, primary_key: true, null: false
      t.text "content", limit: 16.megabytes - 1
      t.string "content_type"
      t.text "enc_item_key"
      t.string "auth_hash"
      t.datetime "created_at", precision: 6
      t.datetime "updated_at", precision: 6
      t.index ["created_at"]
    end
  end
end
