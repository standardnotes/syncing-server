class AddAccessTokenExpiration < ActiveRecord::Migration[5.1]
  def change
    add_column :sessions, :access_expiration, :datetime, after: :refresh_token, null: false, default: -> { 'CURRENT_TIMESTAMP' }
    rename_column :sessions, :expire_at, :refresh_expiration
  end
end
