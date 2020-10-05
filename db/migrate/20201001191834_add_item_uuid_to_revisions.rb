class AddItemUuidToRevisions < ActiveRecord::Migration[5.1]
  def change
    # Revisions must keep the original item uuid with which they were created with,
    # as the uuid is used to generate the authenticated parameters inside the revision's
    # encrypted content payload
    add_column :revisions, :item_uuid, :string, after: :uuid, optional: false
  end
end
