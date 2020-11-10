class SaveRevisionJob < ApplicationJob
  queue_as ENV['SQS_QUEUE_LOW_PRIORITY'] || 'sn_main_low_priority'

  def perform(item_id)
    Octopus.using(:slave1) do
      item = Item.find_by_uuid(item_id)

      unless item
        Rails.logger.warn "Could not find item with uuid #{item_id}"

        return
      end

      last_revision = item.revisions.last

      return save_revision(item) unless last_revision

      last_revision_time = last_revision.created_at

      seconds_from_last_revision = Time.now - last_revision_time
      revisions_frequency = ENV['REVISIONS_FREQUENCY'] ? ENV['REVISIONS_FREQUENCY'].to_i : 300

      save_revision(item) unless seconds_from_last_revision <= revisions_frequency
    end
  rescue StandardError => e
    Rails.logger.error "Could not save revisions for item #{item_id}: #{e.message}"
  end

  def save_revision(item)
    revision = Revision.new
    revision.auth_hash = item.auth_hash
    revision.content = item.content
    revision.content_type = item.content_type
    revision.creation_date = Date.today
    revision.enc_item_key = item.enc_item_key
    revision.item_uuid = item.uuid
    revision.items_key_id = item.items_key_id
    revision.save

    item_revision = ItemRevision.new
    item_revision.item_uuid = item.uuid
    item_revision.revision_uuid = revision.uuid
    item_revision.save
  end
end
