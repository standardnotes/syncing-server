class ArchiveMailer < ApplicationMailer
  attr_accessor :event_publisher

  default from: "Standard Notes <#{ENV['EMAIL_FROM_ADDRESS']}>"

  def initialize
    super
    @event_publisher = SnsPublisher.new
  end

  def data_backup(user_id, extension_id)
    user = User.find(user_id)
    date = Date.today
    data = {
      items: user.items.where(deleted: false),
      auth_params: user.key_params,
    }

    json_data = JSON.pretty_generate(data.as_json({}))

    if json_data.size > ENV['EMAIL_ATTACHMENT_MAX_SIZE'].to_i
      Rails.logger.info "Backup email attachment is too big for user #{user.uuid}" \
                        "(#{(json_data.size / 1.megabyte).round}MB) allowed" \
                        ": #{(ENV['EMAIL_ATTACHMENT_MAX_SIZE'].to_i / 1.megabyte).round}MB"

      settings = ExtensionSetting.find_by_extension_id(extension_id)
      settings = ExtensionSetting.using(:master).create(extension_id: extension_id) if settings.nil?

      return if settings.mute_emails

      return @event_publisher.publish_mail_backup_attachment_too_big(
        user.email,
        settings.uuid,
        json_data.size,
        ENV['EMAIL_ATTACHMENT_MAX_SIZE'].to_i
      )
    end

    attachments["SN-Data-#{date}.txt"] = {
      mime_type: 'application/json',
      content: json_data,
      encoding: 'base64',
    }
    @email = user.email
    mail(to: @email, subject: "Data Backup for #{date}")
  end
end
