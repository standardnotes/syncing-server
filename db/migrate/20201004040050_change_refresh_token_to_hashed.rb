class ChangeRefreshTokenToHashed < ActiveRecord::Migration[5.1]
  def change
    rename_column :sessions, :refresh_token, :hashed_refresh_token
  end
end
