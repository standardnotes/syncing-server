# frozen_string_literal: true

namespace :items do
  desc 'Perform daily backup jobs'

  task :perform_daily_backup_jobs, [:send_email] => [:environment] do |_t, args|
    send_email = args[:send_email].nil?

    items = Item.where(content_type: 'SF|Extension', deleted: false)

    Rails.logger.info "Found #{items.length} extension items to process"

    items.each do |item|
      begin
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

        Rails.logger.info "Enqueueing extensions #{content['name']} for user #{item.user.uuid} and endpoint: #{url.split('?').first}"

        ExtensionJob.perform_later(
          item.user.uuid,
          url,
          item.uuid,
          [],
          !send_email
        )
      rescue StandardError => e
        Rails.logger.error "Failed processing item #{item.uuid}: #{e.message}"
      end
    end

    Rails.logger.info 'Finished processing daily backup jobs'
  end
end
