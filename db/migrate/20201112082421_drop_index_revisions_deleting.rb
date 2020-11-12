class DropIndexRevisionsDeleting < ActiveRecord::Migration[5.2]
  def change
    remove_index :revisions, column: [:item_uuid, :creation_date, :uuid]
  end
end
