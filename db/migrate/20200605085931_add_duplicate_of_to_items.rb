class AddDuplicateOfToItems < ActiveRecord::Migration[5.1]
  def change
    add_column :items, :duplicate_of, :string, limit: 36, :after => :uuid
  end
end
