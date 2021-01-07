# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2021_01_07_122837) do

  create_table "revoked_sessions", primary_key: "uuid", id: :string, limit: 36, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "user_uuid", null: false
    t.datetime "created_at", null: false
    t.index ["user_uuid"], name: "index_revoked_sessions_on_user_uuid"
  end

  create_table "extension_settings", primary_key: "uuid", id: :string, limit: 36, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "extension_id"
    t.boolean "mute_emails", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["extension_id"], name: "index_extension_settings_on_extension_id"
  end

  create_table "item_revisions", primary_key: "uuid", id: :string, limit: 36, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "item_uuid", limit: 36, null: false
    t.string "revision_uuid", limit: 36, null: false
    t.index ["item_uuid"], name: "index_item_revisions_on_item_uuid"
    t.index ["revision_uuid"], name: "index_item_revisions_on_revision_uuid"
  end

  create_table "items", primary_key: "uuid", id: :string, limit: 36, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "duplicate_of", limit: 36
    t.string "items_key_id"
    t.text "content", limit: 16777215
    t.string "content_type"
    t.text "enc_item_key"
    t.string "auth_hash"
    t.string "user_uuid"
    t.boolean "deleted", default: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.text "last_user_agent"
    t.index ["content_type"], name: "index_items_on_content_type"
    t.index ["deleted"], name: "index_items_on_deleted"
    t.index ["updated_at"], name: "index_items_on_updated_at"
    t.index ["user_uuid", "content_type"], name: "index_items_on_user_uuid_and_content_type"
    t.index ["user_uuid", "updated_at", "created_at"], name: "index_items_on_user_uuid_and_updated_at_and_created_at"
    t.index ["user_uuid"], name: "index_items_on_user_uuid"
  end

  create_table "revisions", primary_key: "uuid", id: :string, limit: 36, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "item_uuid"
    t.text "content", limit: 16777215
    t.string "content_type"
    t.string "items_key_id"
    t.text "enc_item_key"
    t.string "auth_hash"
    t.date "creation_date"
    t.datetime "created_at", precision: 6
    t.datetime "updated_at", precision: 6
    t.index ["created_at"], name: "index_revisions_on_created_at"
    t.index ["creation_date"], name: "index_revisions_on_creation_date"
    t.index ["item_uuid"], name: "index_revisions_on_item_uuid"
  end

  create_table "sessions", primary_key: "uuid", id: :string, limit: 36, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "user_uuid"
    t.text "user_agent"
    t.string "api_version"
    t.string "hashed_access_token", null: false
    t.string "hashed_refresh_token", null: false
    t.datetime "access_expiration", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "refresh_expiration", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["updated_at"], name: "index_sessions_on_updated_at"
    t.index ["user_uuid"], name: "index_sessions_on_user_uuid"
  end

  create_table "users", primary_key: "uuid", id: :string, limit: 36, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "email"
    t.string "pw_func"
    t.string "pw_alg"
    t.integer "pw_cost"
    t.integer "pw_key_size"
    t.string "pw_nonce"
    t.string "encrypted_password", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "pw_salt"
    t.string "version"
    t.string "kp_origination"
    t.string "kp_created"
    t.text "updated_with_user_agent"
    t.datetime "locked_until"
    t.integer "num_failed_attempts"
    t.index ["email"], name: "index_users_on_email"
  end

end
