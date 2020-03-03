# frozen_string_literal: true

namespace :items do
  desc 'Perform daily backup jobs'

  task perform_daily_backup_jobs: :environment do
    items = Item.where(content_type: 'SF|Extension', deleted: false)
    items.each do |item|
      content = item.decoded_content
      next unless content && content['frequency'] == 'daily'
      next unless item.user

      if content['subtype'] == 'backup.email_archive'
        ArchiveMailer.data_backup(item.user.uuid).deliver_later
        next
      end

      url = content['url']
      next if url.nil? || url.length.zero?

      begin
        ExtensionJob.perform_later(
          url: url,
          user_id: item.user.uuid,
          extension_id: item.uuid
        )
      rescue StandardError
      end
    end
  end
end
