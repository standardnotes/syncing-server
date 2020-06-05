class DuplicateRevisionsJob < ApplicationJob
  def perform(item_id)
    item = Item.find(item_id)
    original_item_revisions = ItemRevision.where(item_uuid: item.duplicate_of).pluck(:revision_uuid)

    original_item_revisions.each do |revision_uuid|
      ItemRevision.create(item_uuid: item_id, revision_uuid: revision_uuid)
    end
  end
end
