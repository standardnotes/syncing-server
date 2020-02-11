require 'rails_helper'

RSpec.describe Tasks, type: :model do
  describe 'migrate_auth_params_to_revisions' do
    specify do
      user = User.create(pw_cost: 11_000, version: '003', email: 'sn@testing.com', encrypted_password: 'encrypted')

      data = { url: 'https://test.com/revisions' }
      item_one = Item.create(user_uuid: user.uuid, content: "---#{Base64.encode64(JSON.dump(data))}", content_type: 'SF|Extension')

      expect {
        subject.migrate_auth_params_to_revisions
      }.to have_enqueued_job(ExtensionJob)
    end
  end
end
