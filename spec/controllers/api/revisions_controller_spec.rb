require 'rails_helper'

RSpec.describe Api::RevisionsController, type: :controller do
  test_password = '123456'

  let(:test_user) do
    build(:user, password: test_password)
  end

  before(:each) do
    test_user.save

    create_list(:item, 10, :note_type, user_uuid: test_user.uuid, content: 'This is a test note.')
  end

  let(:test_user_credentials) do
    { email: test_user.email, password: test_password }
  end

  let(:test_items) do
    Item.where(user_uuid: test_user.uuid)
  end

  describe 'GET item revisions' do
    context 'when not signed in' do
      it 'should return unauthorized error' do
        item = test_items.first
        get :index, params: { item_id: item.uuid }

        expect(response).to have_http_status(:unauthorized)
        expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')

        parsed_response_body = JSON.parse(response.body)

        expect(parsed_response_body).to_not be_nil
        expect(parsed_response_body['error']).to_not be_nil
        expect(parsed_response_body['error']['message']).to eq('Invalid login credentials.')
        expect(parsed_response_body['error']['tag']).to eq('invalid-auth')
      end
    end
    context 'when signed in' do
      it 'should return item revisions' do
        item = test_items.first

        revision = create(:revision, content: 'This is a first revision')
        create(:item_revision, item_uuid: item.uuid, revision_uuid: revision.uuid)

        @controller = Api::AuthController.new
        post :sign_in, params: test_user_credentials

        @controller = Api::RevisionsController.new
        request.headers['Authorization'] = "bearer #{JSON.parse(response.body)['token']}"

        get :index, params: { item_id: item.uuid }

        expect(response).to have_http_status(:success)
        expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')
        parsed_response_body = JSON.parse(response.body)
        expect(parsed_response_body).not_to include(content: 'This is a first revision')
      end
      it 'should return not found if an item does not exist' do
        @controller = Api::AuthController.new
        post :sign_in, params: test_user_credentials

        @controller = Api::RevisionsController.new
        request.headers['Authorization'] = "bearer #{JSON.parse(response.body)['token']}"

        get :index, params: { item_id: '123456' }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'GET a specific revision' do
    context 'when not signed in' do
      it 'should return unauthorized error' do
        item = test_items.first
        get :show, params: { item_id: item.uuid, id: '12345' }

        expect(response).to have_http_status(:unauthorized)
        expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')

        parsed_response_body = JSON.parse(response.body)

        expect(parsed_response_body).to_not be_nil
        expect(parsed_response_body['error']).to_not be_nil
        expect(parsed_response_body['error']['message']).to eq('Invalid login credentials.')
        expect(parsed_response_body['error']['tag']).to eq('invalid-auth')
      end
    end
    context 'when signed in' do
      it 'should return a specific revision' do
        item = test_items.first

        revision = create(:revision, content: 'This is a first revision')
        create(:item_revision, item_uuid: item.uuid, revision_uuid: revision.uuid)

        @controller = Api::AuthController.new
        post :sign_in, params: test_user_credentials

        @controller = Api::RevisionsController.new
        request.headers['Authorization'] = "bearer #{JSON.parse(response.body)['token']}"

        get :show, params: { item_id: item.uuid, id: revision.uuid }

        expect(response).to have_http_status(:success)
        expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')
        expect(JSON.parse(response.body)['content']).to eq('This is a first revision')
      end
    end
  end
end
