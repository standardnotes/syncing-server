class AddUserAgentToItems < ActiveRecord::Migration[5.0]
  def change
    change_table(:items) do |t|
      t.text :last_user_agent
    end
  end
end
