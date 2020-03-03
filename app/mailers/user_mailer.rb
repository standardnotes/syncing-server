class UserMailer < ApplicationMailer
  def failed_backup(user_id, extension_id, settings_id)
    user = User.find(user_id)
    extension = Item.find(extension_id)
    content = extension.decoded_content

    @ext_name = content['name']
    unless @ext_name
      url = content['url']
      if url.include? 'dbt'
        @ext_name = 'Dropbox'
      elsif url.include? 'gdrive'
        @ext_name = 'Google Drive'
      elsif url.include? 'onedrive'
        @ext_name = 'OneDrive'
      end
    end

    @mute_url = "#{ENV['HOST']}/extension-settings/#{settings_id}/mute"

    mail(to: user.email, subject: "Failed Daily Backup to #{@ext_name}")
  end

  def mfa_disabled(user_id)
    user = User.find(user_id)
    mail(to: user.email, subject: 'Two-factor authentication has been disabled for your account.')
  end
end
