class AddVersion < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :version, :string

    User.transaction do
      User.all.each do |user|
        if user.pw_auth
          user.version = "002"
        else
          user.version = "001"
        end
        user.save
      end
    end
  end
end
