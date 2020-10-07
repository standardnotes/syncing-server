class AddIndexRevisionsItemUuid < ActiveRecord::Migration[5.1]
  def change
    add_index :revisions, :item_uuid, algorithm: :inplace
  end
end
