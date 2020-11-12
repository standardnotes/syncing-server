class DropIndexItemRevisionsDeleting < ActiveRecord::Migration[5.2]
  def change
    remove_index :item_revisions, column: [:item_uuid, :revision_uuid]
  end
end
