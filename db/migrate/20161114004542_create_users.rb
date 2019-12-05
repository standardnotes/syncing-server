class CreateUsers < ActiveRecord::Migration[5.0]
  def change
    create_table :users, :id => false do |t|
      t.string :uuid, limit: 36, primary_key: true, null: false
      t.string :email

      t.string :pw_func
      t.string :pw_alg
      t.integer :pw_cost
      t.integer :pw_key_size
      t.string :pw_nonce

      t.string :encrypted_password, :null => false, :default => ""

      t.timestamps
    end

    add_index :users, :email
  end
end
