require 'rails_helper'

RSpec.describe Api::ItemsController, type: :controller do
	test_user_credentials = { email: 'test@email-sn.org', password: '123456' }

  before(:each) do
    user_manager = SyncEngine::V20190520::UserManager.new(User)
    params = ActionController::Parameters.new({
      pw_cost: 110000,
      version: '003'
    })

    user_manager.register(test_user_credentials[:email], test_user_credentials[:password], params)
  end

  let(:test_user) { 
    User.where(email: test_user_credentials[:email]).first
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
					post :sync, params: { sync_token: '', cursor_token: '', limit: 5, content_type: '', api: '20190520' }

					expect(response).to have_http_status(:unauthorized)
					expect(response.headers["Content-Type"]).to eq("application/json; charset=utf-8")
					
					parsed_response_body = JSON.parse(response.body)

					expect(parsed_response_body).to_not be_nil
					expect(parsed_response_body["error"]).to_not be_nil
					expect(parsed_response_body["error"]["message"]).to eq("Invalid login credentials.")
					expect(parsed_response_body["error"]["tag"]).to eq("invalid-auth") 
				end
			end

			context "when using the fallback api" do
				it "should return results" do
					@controller = Api::AuthController.new
					post :sign_in, params: test_user_credentials

					@controller = Api::ItemsController.new
					request.headers['Authorization'] = "bearer #{JSON.parse(response.body)["token"]}"
					post :sync, params: { sync_token: '', cursor_token: '', limit: 5, content_type: '' }

					expect(response).to have_http_status(:unauthorized)
					expect(response.headers["Content-Type"]).to eq("application/json; charset=utf-8")
					
					parsed_response_body = JSON.parse(response.body)

					expect(parsed_response_body).to_not be_nil
					expect(parsed_response_body["error"]).to_not be_nil
					expect(parsed_response_body["error"]["message"]).to eq("Invalid login credentials.")
					expect(parsed_response_body["error"]["tag"]).to eq("invalid-auth") 
				end
			end
		end
	end
	
	describe "POST backup" do
    context "when not signed in" do
      it "should return unauthorized error" do
        post :backup

        expect(response).to have_http_status(:unauthorized)
        expect(response.headers["Content-Type"]).to eq("application/json; charset=utf-8")
        
        parsed_response_body = JSON.parse(response.body)

        expect(parsed_response_body).to_not be_nil
        expect(parsed_response_body["error"]).to_not be_nil
        expect(parsed_response_body["error"]["message"]).to eq("Invalid login credentials.")
        expect(parsed_response_body["error"]["tag"]).to eq("invalid-auth") 
      end
		end
	end
	
	describe "POST create" do
    context "when not signed in" do
      it "should return unauthorized error" do
        post :create

        expect(response).to have_http_status(:unauthorized)
        expect(response.headers["Content-Type"]).to eq("application/json; charset=utf-8")
        
        parsed_response_body = JSON.parse(response.body)

        expect(parsed_response_body).to_not be_nil
        expect(parsed_response_body["error"]).to_not be_nil
        expect(parsed_response_body["error"]["message"]).to eq("Invalid login credentials.")
        expect(parsed_response_body["error"]["tag"]).to eq("invalid-auth") 
      end
		end
	end
	
	describe "DELETE destroy" do
    context "when not signed in" do
      it "should return unauthorized error" do
        post :destroy

        expect(response).to have_http_status(:unauthorized)
        expect(response.headers["Content-Type"]).to eq("application/json; charset=utf-8")
        
        parsed_response_body = JSON.parse(response.body)

        expect(parsed_response_body).to_not be_nil
        expect(parsed_response_body["error"]).to_not be_nil
        expect(parsed_response_body["error"]["message"]).to eq("Invalid login credentials.")
        expect(parsed_response_body["error"]["tag"]).to eq("invalid-auth") 
      end
		end
  end
end
