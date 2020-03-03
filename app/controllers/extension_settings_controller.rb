class ExtensionSettingsController < ApplicationController
  def mute
    settings = ExtensionSetting.find(params[:id])
    settings.mute_emails = true
    settings.save
  end
end
