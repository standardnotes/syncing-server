require 'rails_helper'

RSpec.describe Admin::AdminController, type: :controller do
  describe 'POST admin/delete_account' do
    before(:all) do
      ENV['ADMIN_KEY'] = 'secret_admin_key'
    end

    it 'should throw unauthorized if not admin_key is not valid' do
      post :delete_account, params: { admin_key: 'something_else' }
      expect(response).to have_http_status(:unauthorized)
      expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')
      expect(JSON.parse(response.body)).to eq({})
    end

    it 'deletes the user if found' do
      user_manager = SyncEngine::V20190520::UserManager.new(User)
      params = ActionController::Parameters.new(
        pw_cost: 110_000,
        version: '003'
      )

      test_registration = user_manager.register('test@testing.com', '123456', params)

      post :delete_account, params: { email: test_registration[:user][:email], admin_key: ENV['ADMIN_KEY'] }
      expect(response).to have_http_status(:ok)
      expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')
      expect(JSON.parse(response.body)).to eq({})

      expect(User.where(email: test_registration[:user][:email])).to_not be_present
    end
  end

  describe 'POST admin/perform_daily_backup_jobs' do
    before(:all) do
      ENV['ADMIN_KEY'] = 'secret_admin_key'
    end

    let(:test_user) do
      build(:user, password: '123456')
    end

    it 'should throw unauthorized if not admin_key is not valid' do
      post :perform_daily_backup_jobs, params: { admin_key: 'something_else' }
      expect(response).to have_http_status(:unauthorized)
      expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')
      expect(JSON.parse(response.body)).to eq({})
    end

    it 'should perform daily backup jobs' do
      create(:item, :backup_daily, user_uuid: test_user.uuid)

      expect do
        post :perform_daily_backup_jobs, params: { admin_key: ENV['ADMIN_KEY'] }
      end.to have_enqueued_job(ExtensionJob)
    end
  end
end
