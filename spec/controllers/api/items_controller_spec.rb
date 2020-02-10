require 'rails_helper'

RSpec.describe Api::ItemsController, type: :controller do
	test_user_credentials = { email: 'test@email-sn.org', password: '123456' }

  before(:each) do
    user_manager = SyncEngine::V20190520::UserManager.new(User)
    params = ActionController::Parameters.new({
      pw_cost: 110000,
      version: '003'
    })

    registration = user_manager.register(test_user_credentials[:email], test_user_credentials[:password], params)

    [*1..10].each do |note_number|
      Item.create(user_uuid: registration[:user][:uuid], content: "Note ##{note_number}", content_type: 'Note')
    end

    data = { frequency: "daily", url: "http://test.com" }
    Item.create(user_uuid: registration[:user][:uuid], content: "---#{Base64.encode64(JSON.dump(data))}", content_type: 'SF|Extension')
  end

  let(:test_user) { 
    User.where(email: test_user_credentials[:email]).first
  }
  
  let(:test_items) {
    Item.where(user_uuid: test_user.uuid)
  }
	
	describe "POST sync" do
    context "when not signed in" do
      it "should return unauthorized error" do
        post :sync

        expect(response).to have_http_status(:unauthorized)
        expect(response.headers["Content-Type"]).to eq("application/json; charset=utf-8")
        
        parsed_response_body = JSON.parse(response.body)

        expect(parsed_response_body).to_not be_nil
        expect(parsed_response_body["error"]).to_not be_nil
        expect(parsed_response_body["error"]["message"]).to eq("Invalid login credentials.")
        expect(parsed_response_body["error"]["tag"]).to eq("invalid-auth") 
      end
		end

		context "when signed in" do
			context "when using api version 20190520" do
				it "should return results" do
					@controller = Api::AuthController.new
					post :sign_in, params: test_user_credentials

					@controller = Api::ItemsController.new
					request.headers['Authorization'] = "bearer #{JSON.parse(response.body)["token"]}"
					post :sync, params: { sync_token: '', cursor_token: '', limit: 5, api: '20190520' }

					expect(response).to have_http_status(:ok)
					expect(response.headers["Content-Type"]).to eq("application/json; charset=utf-8")
					
					parsed_response_body = JSON.parse(response.body)

          expect(parsed_response_body).to_not be_nil
          expect(parsed_response_body["retrieved_items"]).to_not be_nil
          expect(parsed_response_body["saved_items"]).to_not be_nil
          expect(parsed_response_body["sync_token"]).to_not be_nil
          expect(parsed_response_body).to have_key("cursor_token")
				end
			end

			context "when using the fallback api" do
				it "should return results" do
					@controller = Api::AuthController.new
					post :sign_in, params: test_user_credentials

					@controller = Api::ItemsController.new
					request.headers['Authorization'] = "bearer #{JSON.parse(response.body)["token"]}"
					post :sync, params: { sync_token: '', cursor_token: '', limit: 5 }

					expect(response).to have_http_status(:ok)
					expect(response.headers["Content-Type"]).to eq("application/json; charset=utf-8")
					
					parsed_response_body = JSON.parse(response.body)

					expect(parsed_response_body).to_not be_nil
          expect(parsed_response_body["retrieved_items"]).to_not be_nil
          expect(parsed_response_body["saved_items"]).to_not be_nil
          expect(parsed_response_body["sync_token"]).to_not be_nil
          expect(parsed_response_body).to have_key("cursor_token")
				end
			end
		end
	end
	
	describe "POST backup" do
    context "when not signed in" do
      it "should return unauthorized error" do
        item = test_items.where(content_type: 'SF|Extension').first
        post :backup, params: { uuid: item.uuid }

        expect(response).to have_http_status(:unauthorized)
        expect(response.headers["Content-Type"]).to eq("application/json; charset=utf-8")
        
        parsed_response_body = JSON.parse(response.body)

        expect(parsed_response_body).to_not be_nil
        expect(parsed_response_body["error"]).to_not be_nil
        expect(parsed_response_body["error"]["message"]).to eq("Invalid login credentials.")
        expect(parsed_response_body["error"]["tag"]).to eq("invalid-auth") 
      end
    end
    
    context "when signed in" do
      it "should return no content" do
        @controller = Api::AuthController.new
        post :sign_in, params: test_user_credentials

        @controller = Api::ItemsController.new
        request.headers['Authorization'] = "bearer #{JSON.parse(response.body)["token"]}"

        item = test_items.where(content_type: 'SF|Extension').first
        post :backup, params: { uuid: item.uuid }

        expect(response).to have_http_status(:no_content)
        expect(response.headers["Content-Type"]).to be_nil
        expect(response.body).to be_empty
      end
		end
	end
	
	describe "POST create" do
    context "when not signed in" do
      it "should return unauthorized error" do
        new_item = { content: 'Test', content_type: 'Note' }
        post :create, params: { item: new_item }

        expect(response).to have_http_status(:unauthorized)
        expect(response.headers["Content-Type"]).to eq("application/json; charset=utf-8")
        
        parsed_response_body = JSON.parse(response.body)

        expect(parsed_response_body).to_not be_nil
        expect(parsed_response_body["error"]).to_not be_nil
        expect(parsed_response_body["error"]["message"]).to eq("Invalid login credentials.")
        expect(parsed_response_body["error"]["tag"]).to eq("invalid-auth") 
      end
    end
    
    context "when signed in" do
      it "should return results" do
        @controller = Api::AuthController.new
        post :sign_in, params: test_user_credentials

        @controller = Api::ItemsController.new
        request.headers['Authorization'] = "bearer #{JSON.parse(response.body)["token"]}"

        new_item = { content: 'Test', content_type: 'Note' }
        post :create, params: { item: new_item }

        expect(response).to have_http_status(:ok)
        expect(response.headers["Content-Type"]).to eq("application/json; charset=utf-8")
        
        parsed_response_body = JSON.parse(response.body)

        expect(parsed_response_body).to_not be_nil
        expect(parsed_response_body["item"]).to_not be_nil
        expect(parsed_response_body["item"]["content"]).to eq(new_item[:content])
        expect(parsed_response_body["item"]["content_type"]).to eq(new_item[:content_type])
      end
		end
	end
	
	describe "DELETE destroy" do
    context "when not signed in" do
      it "should return unauthorized error" do
        item = test_items.first
        post :destroy, params: { uuid: item.uuid }

        expect(response).to have_http_status(:unauthorized)
        expect(response.headers["Content-Type"]).to eq("application/json; charset=utf-8")
        
        parsed_response_body = JSON.parse(response.body)

        expect(parsed_response_body).to_not be_nil
        expect(parsed_response_body["error"]).to_not be_nil
        expect(parsed_response_body["error"]["message"]).to eq("Invalid login credentials.")
        expect(parsed_response_body["error"]["tag"]).to eq("invalid-auth") 

        item.reload
        expect(item).to be_present
      end
    end
    
    context "when signed in" do
      it "should return no content" do
        @controller = Api::AuthController.new
        post :sign_in, params: test_user_credentials

        @controller = Api::ItemsController.new
        request.headers['Authorization'] = "bearer #{JSON.parse(response.body)["token"]}"

        item = test_items.first
        post :destroy, params: { uuid: item.uuid }

        expect(response).to have_http_status(:no_content)
        expect(response.headers["Content-Type"]).to be_nil
        expect(response.body).to eq("{}")

        expect(Item.where(uuid: item.uuid)).to_not be_present
      end
		end
  end
end
