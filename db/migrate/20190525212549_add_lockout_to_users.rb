class AddLockoutToUsers < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :locked_until, :datetime
    add_column :users, :num_failed_attempts, :integer
  end
end
