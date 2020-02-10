require 'rails_helper'

RSpec.describe ExtensionSettingsController, type: :controller do
  describe 'GET mute' do
    it 'set mute_emails to true' do
      extension_settings = ExtensionSetting.new
      extension_settings.save

      get :mute, params: { id: extension_settings.uuid }

      extension_settings.reload
      expect(extension_settings.mute_emails).to be true
    end
  end
end
