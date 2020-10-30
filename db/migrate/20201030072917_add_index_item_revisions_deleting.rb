class AddIndexItemRevisionsDeleting < ActiveRecord::Migration[5.2]
  def change
    add_index :item_revisions, [:item_uuid, :revision_uuid], algorithm: :inplace
  end
end
