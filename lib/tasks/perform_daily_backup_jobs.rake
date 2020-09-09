# frozen_string_literal: true

namespace :items do
  desc 'Perform daily backup jobs'

  task :perform_daily_backup_jobs, [:send_email] => [:environment] do |_t, args|
    send_email = args[:send_email].nil?

    items = Item.where(content_type: 'SF|Extension', deleted: false)
    items.each do |item|
      content = item.decoded_content
      next unless content && content['frequency'] == 'daily'
      next unless item.user

      if content['subtype'] == 'backup.email_archive'
        if send_email
          ArchiveMailer.data_backup(item.user.uuid).deliver_later
        end
        next
      end

      url = content['url']
      next if url.nil? || url.length.zero?

      ExtensionJob.perform_later(
        item.user.uuid,
        url,
        item.uuid,
        !send_email
      )
    end
  end
end
