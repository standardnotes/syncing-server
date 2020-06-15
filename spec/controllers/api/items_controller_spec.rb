require 'rails_helper'

RSpec.describe Api::ItemsController, type: :controller do
  test_password = '123456'

  let(:test_user) do
    build(:user, password: test_password)
  end

  before(:each) do
    test_user.save

    create_list(:item, 10, :note_type, user_uuid: test_user.uuid, content: 'This is a test note.')
    create(:item, :backup_daily, user_uuid: test_user.uuid)
    create(:item, :backup_realtime, user_uuid: test_user.uuid)
  end

  let(:test_user_credentials) do
    { email: test_user.email, password: test_password }
  end

  let(:test_items) do
    Item.where(user_uuid: test_user.uuid)
  end

  let(:note_item) do
    Item.where(user_uuid: test_user.uuid, content_type: 'Note').first
  end

  describe 'POST sync' do
    context 'when not signed in' do
      it 'should return unauthorized error' do
        post :sync

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
      context 'when using api version 20190520' do
        context 'and no items are sent to be updated' do
          it 'should return existing items' do
            @controller = Api::AuthController.new
            post :sign_in, params: test_user_credentials

            @controller = Api::ItemsController.new
            request.headers['Authorization'] = "bearer #{JSON.parse(response.body)['token']}"

            post :sync, params: { api: '20190520', content_type: 'Note' }

            expect(response).to have_http_status(:ok)
            expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')

            parsed_response_body = JSON.parse(response.body)

            expect(parsed_response_body).to_not be_nil
            expect(parsed_response_body['retrieved_items']).to_not be_nil
            expect(parsed_response_body['sync_token']).to_not be_nil
            expect(parsed_response_body).to have_key('cursor_token')

            saved_items = parsed_response_body['saved_items']
            expect(saved_items.count).to be_equal(0)

            retrieved_items = parsed_response_body['retrieved_items']
            note_items = test_items.where(content_type: 'Note')
            expect(retrieved_items.count).to be_equal(note_items.count)

            retrieved_items = serialize_to_hash(retrieved_items)
            note_items = note_items.to_a.map(&:serializable_hash)

            note_items = serialize_to_hash(note_items)
            expect(retrieved_items).to match_array(note_items)
          end
        end

        context 'and modifying note contents' do
          it 'should return results matching the new changes' do
            @controller = Api::AuthController.new
            post :sign_in, params: test_user_credentials

            @controller = Api::ItemsController.new
            request.headers['Authorization'] = "bearer #{JSON.parse(response.body)['token']}"

            # Serializing the items into an array of hashes
            items_param = test_items.limit(5).to_a.map(&:serializable_hash)
            items_param[0]['content'] = 'This is the new content.'
            items_param[1]['content'] = 'And this too.'

            post :sync, params: { sync_token: '', cursor_token: '', limit: 5, api: '20190520', items: items_param }

            expect(response).to have_http_status(:ok)
            expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')

            parsed_response_body = JSON.parse(response.body)

            expect(parsed_response_body).to_not be_nil
            expect(parsed_response_body['retrieved_items']).to_not be_nil
            expect(parsed_response_body['sync_token']).to_not be_nil
            expect(parsed_response_body).to have_key('cursor_token')

            saved_items = parsed_response_body['saved_items']
            expect(saved_items).to_not be_nil

            expect(saved_items.count).to be_equal(items_param.count)

            saved_items = serialize_to_hash(saved_items)

            items_param = serialize_to_hash(items_param)
            expect(saved_items).to match_array(items_param)
          end
          it 'should store revisions matching changes' do
            @controller = Api::AuthController.new
            post :sign_in, params: test_user_credentials

            @controller = Api::ItemsController.new
            request.headers['Authorization'] = "bearer #{JSON.parse(response.body)['token']}"

            # Serializing the items into an array of hashes
            items_param = [note_item].to_a.map(&:serializable_hash)

            items_param[0]['content'] = 'This is the new content.'
            post :sync, params: { sync_token: '', cursor_token: '', limit: 5, api: '20190520', items: items_param }
            expect(response).to have_http_status(:success)

            items_param[0] = JSON.parse(response.body)['saved_items'].first
            items_param[0]['content'] = 'This is yet another new content.'
            post :sync, params: { sync_token: '', cursor_token: '', limit: 5, api: '20190520', items: items_param }
            expect(response).to have_http_status(:success)

            item = Item.where(uuid: items_param[0]['uuid']).first

            revisions = item.revisions

            expect(CleanupRevisionsJob).to have_been_enqueued.with(item.uuid, 30).exactly(3).times
            expect(revisions.count).to eq(3)
            expect(revisions[0].content).to eq('This is yet another new content.')
            expect(revisions[1].content).to eq('This is the new content.')
          end
        end

        context 'and deleting items' do
          it 'should return results matching the new changes' do
            @controller = Api::AuthController.new
            post :sign_in, params: test_user_credentials

            @controller = Api::ItemsController.new
            request.headers['Authorization'] = "bearer #{JSON.parse(response.body)['token']}"

            # Serializing the items into an array of hashes
            items_param = test_items.limit(3).to_a.map(&:serializable_hash)
            items_param[0]['deleted'] = true

            post :sync, params: { limit: 5, api: '20190520', items: items_param }

            expect(response).to have_http_status(:ok)
            expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')

            parsed_response_body = JSON.parse(response.body)

            expect(parsed_response_body).to_not be_nil
            expect(parsed_response_body['retrieved_items']).to_not be_nil
            expect(parsed_response_body['sync_token']).to_not be_nil
            expect(parsed_response_body).to have_key('cursor_token')

            saved_items = parsed_response_body['saved_items']
            expect(saved_items).to_not be_nil

            expect(saved_items.count).to be_equal(items_param.count)

            saved_items = serialize_to_hash(saved_items)
            items_param = serialize_to_hash(items_param)

            expect(saved_items[0][:uuid]).to match(items_param[0][:uuid])
            expect(saved_items[0][:user_uuid]).to match(items_param[0][:user_uuid])
            expect(saved_items[0][:content]).to be_nil
            expect(saved_items[0][:content_type]).to match(items_param[0][:content_type])
            expect(saved_items[0][:deleted]).to be true

            expect(saved_items[1]).to match(items_param[1])
            expect(saved_items[2]).to match(items_param[2])
          end
        end

        context 'and syncing items along with new ones' do
          it 'should return results matching the new changes' do
            @controller = Api::AuthController.new
            post :sign_in, params: test_user_credentials

            @controller = Api::ItemsController.new
            request.headers['Authorization'] = "bearer #{JSON.parse(response.body)['token']}"

            # Serializing the items into an array of hashes
            items_param = test_items.limit(3).to_a.map(&:serializable_hash)

            # Updating an existing item
            items_param[0]['deleted'] = true
            items_param[1]['content'] = 'Updated note #1.'
            items_param[2]['content'] = 'Updated note #2.'

            # Creating an item
            new_item_uuid = SecureRandom.uuid
            new_item = build(:item, :note_type, uuid: new_item_uuid, user_uuid: test_user.uuid, content: 'New item.')
            new_item.created_at = new_item.updated_at = DateTime.now

            new_item = [new_item].to_a.map(&:serializable_hash)[0]
            items_param.push(new_item)

            sync_token = Base64.encode64('2:' + DateTime.now.to_f.to_s)
            post :sync, params: { sync_token: sync_token, limit: 5, api: '20190520', items: items_param }

            expect(response).to have_http_status(:ok)
            expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')

            parsed_response_body = JSON.parse(response.body)

            expect(parsed_response_body).to_not be_nil
            expect(parsed_response_body['retrieved_items']).to_not be_nil
            expect(parsed_response_body['sync_token']).to_not be_nil
            expect(parsed_response_body).to have_key('cursor_token')

            saved_items = parsed_response_body['saved_items']
            expect(saved_items).to_not be_nil

            expect(saved_items.count).to be_equal(items_param.count)

            saved_items = serialize_to_hash(saved_items)
            items_param = serialize_to_hash(items_param)

            expect(saved_items[0][:uuid]).to match(items_param[0][:uuid])
            expect(saved_items[0][:user_uuid]).to match(items_param[0][:user_uuid])
            expect(saved_items[0][:content]).to be_nil
            expect(saved_items[0][:content_type]).to match(items_param[0][:content_type])
            expect(saved_items[0][:deleted]).to be true

            expect(saved_items[1]).to match(items_param[1])
            expect(saved_items[2]).to match(items_param[2])
            expect(saved_items[3]).to match(items_param[3])
          end
        end
      end

      context 'when using the fallback api' do
        it 'should return results' do
          @controller = Api::AuthController.new
          post :sign_in, params: test_user_credentials

          @controller = Api::ItemsController.new
          request.headers['Authorization'] = "bearer #{JSON.parse(response.body)['token']}"
          post :sync, params: { sync_token: '', cursor_token: '', limit: 5, items: [test_items] }

          expect(response).to have_http_status(:ok)
          expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')

          parsed_response_body = JSON.parse(response.body)

          expect(parsed_response_body).to_not be_nil
          expect(parsed_response_body['retrieved_items']).to_not be_nil
          expect(parsed_response_body['saved_items']).to_not be_nil
          expect(parsed_response_body['sync_token']).to_not be_nil
          expect(parsed_response_body).to have_key('cursor_token')
        end
      end

      context 'when using an invalid api' do
        it 'should throw an exception' do
          expect do
            @controller = Api::AuthController.new
            post :sign_in, params: test_user_credentials

            @controller = Api::ItemsController.new
            request.headers['Authorization'] = "bearer #{JSON.parse(response.body)['token']}"
            post :sync, params: { api: '00000000' }
          end.to raise_error(Api::ApiController::InvalidApiVersion)
        end
      end
    end
  end

  describe 'POST backup' do
    context 'when not signed in' do
      it 'should return unauthorized error' do
        item = test_items.where(content_type: 'SF|Extension').first
        post :backup, params: { uuid: item.uuid }

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
      it 'should return no content' do
        @controller = Api::AuthController.new
        post :sign_in, params: test_user_credentials

        @controller = Api::ItemsController.new
        request.headers['Authorization'] = "bearer #{JSON.parse(response.body)['token']}"

        item = test_items.where(content_type: 'SF|Extension').first
        post :backup, params: { uuid: item.uuid }

        expect(response).to have_http_status(:no_content)
        expect(response.headers['Content-Type']).to be_nil
        expect(response.body).to be_empty
      end
    end
  end

  describe 'POST create' do
    context 'when not signed in' do
      it 'should return unauthorized error' do
        new_item = { content: 'Test', content_type: 'Note' }
        post :create, params: { item: new_item }

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
      it 'should return results' do
        @controller = Api::AuthController.new
        post :sign_in, params: test_user_credentials

        @controller = Api::ItemsController.new
        request.headers['Authorization'] = "bearer #{JSON.parse(response.body)['token']}"

        new_item = { content: 'Test', content_type: 'Note' }
        post :create, params: { item: new_item }

        expect(response).to have_http_status(:ok)
        expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')

        parsed_response_body = JSON.parse(response.body)

        expect(parsed_response_body).to_not be_nil
        expect(parsed_response_body['item']).to_not be_nil
        expect(parsed_response_body['item']['content']).to eq(new_item[:content])
        expect(parsed_response_body['item']['content_type']).to eq(new_item[:content_type])
      end
      it 'should duplicate revisions for a conflicting item' do
        @controller = Api::AuthController.new
        post :sign_in, params: test_user_credentials

        @controller = Api::ItemsController.new
        request.headers['Authorization'] = "bearer #{JSON.parse(response.body)['token']}"

        new_item = { content: 'Test', content_type: 'Note', duplicate_of: '1-2-3' }
        post :create, params: { item: new_item }
        expect(response).to have_http_status(:success)

        expect(DuplicateRevisionsJob).to have_been_enqueued
      end
    end
  end

  describe 'DELETE destroy' do
    context 'when not signed in' do
      it 'should return unauthorized error' do
        item = test_items.first
        post :destroy, params: { uuid: item.uuid }

        expect(response).to have_http_status(:unauthorized)
        expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')

        parsed_response_body = JSON.parse(response.body)

        expect(parsed_response_body).to_not be_nil
        expect(parsed_response_body['error']).to_not be_nil
        expect(parsed_response_body['error']['message']).to eq('Invalid login credentials.')
        expect(parsed_response_body['error']['tag']).to eq('invalid-auth')

        item.reload
        expect(item).to be_present
      end
    end

    context 'when signed in' do
      it 'should return no content' do
        @controller = Api::AuthController.new
        post :sign_in, params: test_user_credentials

        @controller = Api::ItemsController.new
        request.headers['Authorization'] = "bearer #{JSON.parse(response.body)['token']}"

        item = test_items.first
        post :destroy, params: { uuid: item.uuid }

        expect(response).to have_http_status(:no_content)
        expect(response.headers['Content-Type']).to be_nil
        expect(response.body).to eq('{}')

        expect(Item.where(uuid: item.uuid)).to_not be_present
      end
    end
  end
end
