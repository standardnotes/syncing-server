class RemovePwAuth < ActiveRecord::Migration[5.0]
  def change
    remove_column :users, :pw_auth
  end
end
