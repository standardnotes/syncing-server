class CreateArchivedSessions < ActiveRecord::Migration[5.2]
  def change
    create_table :archived_sessions, id: false do |t|
      t.string :uuid, limit: 36, primary_key: true, null: false
      t.string :user_uuid, null: false
      t.datetime :created_at, null: false
    end

    add_index :archived_sessions, :user_uuid
  end
end
