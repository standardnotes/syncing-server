class Schedule::ScheduleController < ApplicationController
  before_action do
    admin_key = params[:admin_key]
    env_admin_key = ENV['ADMIN_KEY']
    if !admin_key || !env_admin_key || !ActiveSupport::SecurityUtils.secure_compare(admin_key, env_admin_key)
      render json: {}, status: 401
    end
  end

  respond_to :json

  def perform_daily_backup_jobs
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
