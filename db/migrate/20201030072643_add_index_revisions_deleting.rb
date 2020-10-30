class AddIndexRevisionsDeleting < ActiveRecord::Migration[5.2]
  def change
    add_index :revisions, [:item_uuid, :creation_date, :uuid], algorithm: :inplace
  end
end
