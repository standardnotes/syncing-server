class AccountCleanupJob < ApplicationJob
  def perform(user_id)
    Rails.logger.info "Performing account cleanup job for user: #{user_id}"

    Item.using(:slave1).where(user_uuid: user_id).find_each do |item|
      Octopus.using(:master) do
        Revision.where(item_uuid: item.uuid).delete_all
        ItemRevision.where(item_uuid: item.uuid).delete_all
        item.delete
      end
    end

    Rails.logger.info "Finished account cleanup job for user: #{user_id}"
  end
end
