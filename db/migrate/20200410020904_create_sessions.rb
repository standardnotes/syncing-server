class CreateSessions < ActiveRecord::Migration[5.1]
  def change
    create_table :sessions, :id => false do |t|
      t.string :uuid, limit: 36, primary_key: true, null: false
      t.string :user_uuid
      t.text :user_agent
      t.string :api_version
      t.string :access_token, null: false
      t.string :refresh_token, null: false
      t.datetime :expire_at, null: false

      t.timestamps
    end

    add_index :sessions, :user_uuid
    add_index :sessions, :access_token, unique: true
    add_index :sessions, :refresh_token, unique: true
    add_index :sessions, :updated_at
  end
end
