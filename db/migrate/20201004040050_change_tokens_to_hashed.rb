class ChangeTokensToHashed < ActiveRecord::Migration[5.1]
  def change
    remove_index :sessions, column: :access_token
    remove_index :sessions, column: :refresh_token
    rename_column :sessions, :access_token, :hashed_access_token
    rename_column :sessions, :refresh_token, :hashed_refresh_token
  end
end
