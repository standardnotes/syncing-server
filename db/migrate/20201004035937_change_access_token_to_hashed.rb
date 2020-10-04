class ChangeAccessTokenToHashed < ActiveRecord::Migration[5.1]
  def change
    rename_column :sessions, :access_token, :hashed_access_token
  end
end
