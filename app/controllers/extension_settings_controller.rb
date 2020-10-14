class ExtensionSettingsController < ApplicationController
  def mute
    settings = ExtensionSetting.find(params[:id])
    settings.mute_emails = true
    settings.save

    render plain: 'Emails successfully muted'
  end
end
