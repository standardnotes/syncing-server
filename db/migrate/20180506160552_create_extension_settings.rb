class CreateExtensionSettings < ActiveRecord::Migration[5.0]
  def change
    create_table :extension_settings, id: false do |t|
      t.string :uuid, limit: 36, primary_key: true, null: false
      t.string :extension_id
      t.boolean :mute_emails, :default => false
      t.timestamps
    end

    add_index :extension_settings, :extension_id
  end
end
