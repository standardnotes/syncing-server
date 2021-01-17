class AddReceivedToRevokedSessions < ActiveRecord::Migration[5.2]
  def change
    add_column :revoked_sessions, :received, :boolean, default: false, null: false
  end
end
