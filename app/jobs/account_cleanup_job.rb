class AccountCleanupJob < ApplicationJob
  def perform(user_id)
    Rails.logger.info "Performing account cleanup job for user: #{user_id}"

    user = User.find(user_id)

    extensions = user.items.where(content_type: 'SF|Extension', deleted: false)
    extensions.each do |ext|
      content = ext.decoded_content
      next unless content
      frequency = content['frequency']
      next if frequency != 'realtime'

      ExtensionJob.perform_later(
        user.uuid,
        "#{content['url']}&directive=delete-account",
        ext.uuid,
        [],
        true
      )
    end

    Item.using(:slave1).where(user_uuid: user_id).find_each do |item|
      Octopus.using(:master) do
        Revision.where(item_uuid: item.uuid).delete_all
        ItemRevision.where(item_uuid: item.uuid).delete_all
        Item.where(uuid: item.uuid).delete_all
      end
    end

    user.destroy

    Rails.logger.info "Finished account cleanup job for user: #{user_id}"
  end
end
