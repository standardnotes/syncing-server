class ArchiveMailer < ApplicationMailer
  default from: 'Standard Notes <backups@standardnotes.org>'

  def data_backup(user_id)
    user = User.find(user_id)
    date = Date.today
    data = {
      items: user.items.where(deleted: false),
      auth_params: user.auth_params,
    }
    attachments["SN-Data-#{date}.txt"] = {
      mime_type: 'application/json',
      content: JSON.pretty_generate(data.as_json({})),
    }
    @email = user.email
    mail(to: @email, subject: "Data Backup for #{date}")
  end
end
