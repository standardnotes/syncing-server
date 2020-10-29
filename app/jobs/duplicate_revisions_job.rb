class DuplicateRevisionsJob < ApplicationJob
  queue_as ENV['SQS_QUEUE_LOW_PRIORITY'] || 'sn_main_low_priority'

  def perform(item_id)
    distribute_reads do
      item = Item.find_by_uuid(item_id)

      unless item
        Rails.logger.warn "Could not find item with uuid #{item_id}"

        return
      end

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
  rescue StandardError => e
    Rails.logger.error "Could duplicate revisions for item #{item_id}: #{e.message}"
  end
end
