class AddUserAgentToUser < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :updated_with_user_agent, :text
  end
end
