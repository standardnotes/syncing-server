class Tasks < ApplicationRecord

  def self.perform_daily_backup_jobs
    items = Item.where(:content_type => "SF|Extension", "deleted" => false)
    items.each do |item|
      content = item.decoded_content
      if content && content["frequency"] == "daily"

        next if !item.user

        if content["subtype"] == "backup.email_archive"
          ArchiveMailer.data_backup(item.user.uuid).deliver_later
          next
        end

        url = content["url"]
        next if url == nil || url.length == 0

        begin
          ExtensionJob.perform_later({
            url: url,
            user_id: item.user.uuid,
            extension_id: item.uuid
            })
        rescue
        end
      end

    end
  end

  def self.migrate_auth_params_to_revisions
    items = Item.where(:content_type => "SF|Extension", "deleted" => false)
    items.each do |item|
      content = item.decoded_content
      url = content["url"]
      if url && url.include?("revisions") && item.user
        params = {
          url: url,
          user_id: item.user.uuid,
          extension_id: item.uuid,
          auth_params_op: true
        }
        ExtensionJob.perform_later(params)
      end
    end
  end

end
