class ExtensionSettingsController < ApplicationController
  def mute
    settings = ExtensionSetting.find(params[:id])
    settings.mute_emails = true
    settings.save

    render plain: 'This email has been muted. To unmute, reinstall this extension.'
  end
end
