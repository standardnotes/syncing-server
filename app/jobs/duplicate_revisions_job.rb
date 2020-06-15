class DuplicateRevisionsJob < ApplicationJob
  def perform(item_id)
    item = Item.find(item_id)

    existing_original_item = Item
      .where(uuid: item.duplicate_of, user_uuid: item.user_uuid)
      .first

    if existing_original_item
      original_item_revisions = existing_original_item
        .item_revisions
        .pluck(:revision_uuid)

      original_item_revisions.each do |revision_uuid|
        ItemRevision.create(item_uuid: item_id, revision_uuid: revision_uuid)
      end
    end
  end
end
