class AddKeyParamFields < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :kp_origination, :string, optional: true, after: :version
    add_column :users, :kp_created, :string, optional: true, after: :kp_origination
  end
end
