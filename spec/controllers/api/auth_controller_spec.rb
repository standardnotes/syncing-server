require 'rails_helper'

RSpec.describe Api::AuthController, type: :controller do
  test_password = '123456'

  let(:test_user) do
    build(:user, password: test_password)
  end

  let(:test_user_004) do
    build(:user, password: test_password, version: '004')
  end

  let(:test_user_credentials) do
    { email: test_user.email, password: test_password }
  end

  let(:test_user_004_credentials) do
    { email: test_user_004.email, password: test_password, api_version: '20200115' }
  end

  let(:auth_params_keys) do
    %w[identifier pw_cost pw_nonce version].sort
  end

  let(:mfa_item) do
    create(:item, :mfa_type, user_uuid: test_user.uuid)
  end

  describe 'GET auth/params' do
    context 'when the provided email does not belong to a user' do
      it 'should return the params' do
        get :auth_params, params: { email: 'test@email.com' }

        expect(response).to have_http_status(:ok)
        expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')

        parsed_response_body = JSON.parse(response.body)

        expect(parsed_response_body.keys.sort).to contain_exactly(*auth_params_keys)
        expect(parsed_response_body['identifier']).to eq 'test@email.com'
        expect(parsed_response_body['pw_cost']).to_not be_nil
        expect(parsed_response_body['pw_nonce']).to_not be_nil
        expect(parsed_response_body['version']).to_not be_nil
      end
    end

    context 'when the provided email belongs to a user' do
      it 'should return the params' do
        get :auth_params, params: { email: test_user.email }

        expect(response).to have_http_status(:ok)
        expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')

        parsed_response_body = JSON.parse(response.body)

        expect(parsed_response_body.keys.sort).to contain_exactly(*auth_params_keys)
        expect(parsed_response_body['identifier']).to eq test_user.email
        expect(parsed_response_body['version']).to_not be_nil
      end
    end
  end

  describe 'POST auth/sign_in' do
    context 'when no crendentials are provided' do
      it 'sign in should fail' do
        post :sign_in

        expect(response).to have_http_status(:unauthorized)
        expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')
        parsed_response_body = JSON.parse(response.body)

        expect(parsed_response_body).to_not be_nil
        expect(parsed_response_body['error']).to_not be_nil
        expect(parsed_response_body['error']['message']).to eq('Invalid login credentials.')
      end
    end

    context 'when invalid crendentials are provided' do
      it 'sign in should fail' do
        post :sign_in, params: { email: test_user.email, password: 'invalid-password' }

        expect(response).to have_http_status(:unauthorized)
        expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')
        parsed_response_body = JSON.parse(response.body)

        expect(parsed_response_body).to_not be_nil
        expect(parsed_response_body['error']).to_not be_nil
        expect(parsed_response_body['error']['message']).to eq('Invalid email or password.')
      end
    end

    context 'when invalid crendentials are provided multiple times' do
      it 'sign in should fail and user should be locked' do
        [*1..6].each do |_login_attempt|
          post :sign_in, params: { email: test_user.email, password: 'invalid-password' }
        end

        expect(response).to have_http_status(:unauthorized)
        expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')
        parsed_response_body = JSON.parse(response.body)

        expect(parsed_response_body).to_not be_nil
        expect(parsed_response_body['error']).to_not be_nil
        expect(parsed_response_body['error']['message']).to eq('Invalid email or password.')

        test_user.reload
        expect(test_user.num_failed_attempts).to eq(0)
        expect(test_user.locked_until.future?).to be true

        post :sign_in, params: { email: test_user.email, password: 'invalid-password' }
        parsed_response_body = JSON.parse(response.body)

        expect(response).to have_http_status(:locked)
        expect(parsed_response_body).to_not be_nil
        expect(parsed_response_body['error']).to_not be_nil
        expect(parsed_response_body['error']['message']).to eq('Too many successive login requests. '\
          'Please try your request again later.')
      end
    end

    context 'when valid crendentials are provided' do
      it 'sign in should not fail' do
        post :sign_in, params: test_user_credentials

        expect(response).to have_http_status(:ok)
        expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')
        parsed_response_body = JSON.parse(response.body)

        expect(parsed_response_body).to_not be_nil
        expect(parsed_response_body['user']).to_not be_nil
        expect(parsed_response_body['user']['email']).to eq(test_user_credentials[:email])
        expect(parsed_response_body['token']).to_not be_nil
      end
    end

    context 'when using MFA' do
      context 'when mfa param key is not provided' do
        it 'sign in should fail' do
          mfa_item.save
          post :sign_in, params: test_user_credentials

          expect(response).to have_http_status(:unauthorized)
          expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')
          parsed_response_body = JSON.parse(response.body)

          expect(parsed_response_body).to_not be_nil
          expect(parsed_response_body['error']).to_not be_nil
          expect(parsed_response_body['error']['tag']).to eq('mfa-required')
          expect(parsed_response_body['error']['message']).to eq('Please enter your two-factor authentication code.')
          expect(parsed_response_body['error']['payload']['mfa_key']).to eq("mfa_#{mfa_item.uuid}")
        end
      end

      context 'when mfa param key is provided' do
        it 'sign in should fail' do
          mfa_item.save
          post :sign_in, params: test_user_credentials.merge("mfa_#{mfa_item.uuid}": '000000')

          expect(response).to have_http_status(:unauthorized)
          expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')
          parsed_response_body = JSON.parse(response.body)

          expect(parsed_response_body).to_not be_nil
          expect(parsed_response_body['error']).to_not be_nil
          expect(parsed_response_body['error']['tag']).to eq('mfa-invalid')
          expect(parsed_response_body['error']['message']).to eq('The two-factor authentication code '\
            'you entered is incorrect. Please try again.')

          expect(parsed_response_body['error']['payload']['mfa_key']).to eq("mfa_#{mfa_item.uuid}")
        end
      end
    end
  end

  describe 'POST auth/register' do
    context 'when no parameters are provided' do
      it 'register should fail' do
        post :register

        expect(response).to have_http_status(:unauthorized)
        expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')
        parsed_response_body = JSON.parse(response.body)

        expect(parsed_response_body).to_not be_nil
        expect(parsed_response_body['error']).to_not be_nil
        expect(parsed_response_body['error']['message']).to eq('Please enter an email and a password to register.')
      end
    end

    context 'when registering with an existing email' do
      it 'register should fail' do
        post :register, params: { email: test_user_credentials[:email], password: test_user_credentials[:password] }

        expect(response).to have_http_status(:unauthorized)
        expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')
        parsed_response_body = JSON.parse(response.body)

        expect(parsed_response_body).to_not be_nil
        expect(parsed_response_body['error']).to_not be_nil
        expect(parsed_response_body['error']['message']).to eq('This email is already registered.')
      end
    end

    context 'when valid parameters are provided' do
      it 'register should not fail' do
        new_user_email = 'new-user@sn-email.org'
        post :register, params: { email: new_user_email, password: '123456' }

        expect(response).to have_http_status(:ok)
        expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')
        parsed_response_body = JSON.parse(response.body)

        expect(parsed_response_body).to_not be_nil
        expect(parsed_response_body['user']).to_not be_nil
        expect(parsed_response_body['user']['email']).to eq(new_user_email)
        expect(parsed_response_body['token']).to_not be_nil
      end
    end
  end

  describe 'POST auth/update' do
    context 'when user is not authenticated' do
      it 'should return an error' do
        post :update, params: { email: test_user.email }

        expect(response).to have_http_status(:unauthorized)
        expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')
        parsed_response_body = JSON.parse(response.body)

        expect(parsed_response_body).to_not be_nil
        expect(parsed_response_body['error']).to_not be_nil
        expect(parsed_response_body['error']['message']).to eq('Invalid login credentials.')
        expect(parsed_response_body['error']['tag']).to eq('invalid-auth')
      end
    end

    context 'when user is authenticated' do
      it 'should be updated' do
        post :sign_in, params: test_user_credentials

        request.headers['Authorization'] = "bearer #{JSON.parse(response.body)['token']}"
        post :update, params: { version: '002' }

        expect(response).to have_http_status(:ok)
        expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')
        parsed_response_body = JSON.parse(response.body)

        expect(parsed_response_body).to_not be_nil
        expect(parsed_response_body['user']).to_not be_nil
        expect(parsed_response_body['user']['email']).to eq(test_user_credentials[:email])
        expect(parsed_response_body['token']).to_not be_nil

        test_user.reload
        expect(test_user.version).to eq('002')
      end
    end
  end

  describe 'POST auth/change_pw' do
    context 'when not authenticated' do
      it 'change password should fail' do
        post :change_pw, params: {}

        expect(response).to have_http_status(:unauthorized)
        expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')
        parsed_response_body = JSON.parse(response.body)

        expect(parsed_response_body).to_not be_nil
        expect(parsed_response_body['error']).to_not be_nil
        expect(parsed_response_body['error']['message']).to eq('Invalid login credentials.')
      end
    end

    context 'when current password is not provided' do
      it 'change password should fail' do
        post :sign_in, params: test_user_credentials

        request.headers['Authorization'] = "bearer #{JSON.parse(response.body)['token']}"
        post :change_pw, params: {}

        expect(response).to have_http_status(:unauthorized)
        expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')
        parsed_response_body = JSON.parse(response.body)

        expect(parsed_response_body).to_not be_nil
        expect(parsed_response_body['error']).to_not be_nil
        expect(parsed_response_body['error']['message']).to eq('Your current password is required '\
          'to change your password. Please update your application if you do not see this option.')
      end
    end

    context 'when password nonce is not provided' do
      it 'change password should fail' do
        post :sign_in, params: test_user_credentials

        request.headers['Authorization'] = "bearer #{JSON.parse(response.body)['token']}"
        post :change_pw, params: { current_password: test_user_credentials[:password] }

        expect(response).to have_http_status(:unauthorized)
        expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')
        parsed_response_body = JSON.parse(response.body)

        expect(parsed_response_body).to_not be_nil
        expect(parsed_response_body['error']).to_not be_nil
        expect(parsed_response_body['error']['message']).to eq('The change password request is '\
          'missing new auth parameters. Please try again.')
      end
    end

    context 'when parameters are provided' do
      context 'and current password is invalid' do
        it 'change password should fail' do
          post :sign_in, params: test_user_credentials

          request.headers['Authorization'] = "bearer #{JSON.parse(response.body)['token']}"
          post :change_pw, params: {
            current_password: 'not-the-current-password',
            new_password: 'new-pwd',
            pw_nonce: test_user.pw_nonce,
          }

          expect(response).to have_http_status(:unauthorized)
          expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')
          parsed_response_body = JSON.parse(response.body)

          expect(parsed_response_body).to_not be_nil
          expect(parsed_response_body['error']).to_not be_nil
          expect(parsed_response_body['error']['message']).to eq('The current password you '\
            'entered is incorrect. Please try again.')
        end
      end

      context 'and current password is valid' do
        it 'change password should not fail and password should be updated' do
          post :sign_in, params: test_user_credentials

          request.headers['Authorization'] = "bearer #{JSON.parse(response.body)['token']}"
          post :change_pw, params: {
            current_password: test_user_credentials[:password],
            new_password: 'new-pwd',
            pw_nonce: test_user.pw_nonce,
          }

          expect(response).to have_http_status(:ok)
          expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')
          parsed_response_body = JSON.parse(response.body)

          expect(parsed_response_body).to_not be_nil
          expect(parsed_response_body['user']).to_not be_nil
          expect(parsed_response_body['user']['email']).to eq(test_user_credentials[:email])
          expect(parsed_response_body['token']).to_not be_nil

          post :sign_in, params: { email: test_user_credentials[:email], password: 'new-pwd' }

          expect(response).to have_http_status(:ok)
          expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')
          parsed_response_body = JSON.parse(response.body)

          expect(parsed_response_body).to_not be_nil
          expect(parsed_response_body['user']).to_not be_nil
          expect(parsed_response_body['user']['email']).to eq(test_user_credentials[:email])
          expect(parsed_response_body['token']).to_not be_nil
        end
      end
    end
  end

  describe 'authenticate_user' do
    context 'when an invalid Authorization header value is passed' do
      it 'should return unauthorized error' do
        request.headers['Authorization'] = 'invalid-token'
        post :update, params: { version: '002' }

        expect(response).to have_http_status(:unauthorized)
        expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')
        parsed_response_body = JSON.parse(response.body)

        expect(parsed_response_body).to_not be_nil
        expect(parsed_response_body['error']).to_not be_nil
        expect(parsed_response_body['error']['message']).to eq('Invalid login credentials.')
      end
    end

    context 'when an invalid token is used' do
      it 'should return unauthorized error' do
        request.headers['Authorization'] = 'bearer xxx'

        post :update, params: { version: '002' }

        expect(response).to have_http_status(:unauthorized)
        expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')
        parsed_response_body = JSON.parse(response.body)

        expect(parsed_response_body).to_not be_nil
        expect(parsed_response_body['error']).to_not be_nil
        expect(parsed_response_body['error']['message']).to eq('Invalid login credentials.')
      end
    end

    context 'when the user signs in, changes their password and still use their old JWT' do
      it 'should return unauthorized error' do
        post :sign_in, params: test_user_credentials

        request.headers['Authorization'] = "bearer #{JSON.parse(response.body)['token']}"
        post :change_pw, params: {
          current_password: test_user_credentials[:password],
          new_password: 'new-pwd',
          pw_nonce: test_user.pw_nonce,
        }

        post :update, params: { version: '002' }

        expect(response).to have_http_status(:unauthorized)
        expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')
        parsed_response_body = JSON.parse(response.body)

        expect(parsed_response_body).to_not be_nil
        expect(parsed_response_body['error']).to_not be_nil
        expect(parsed_response_body['error']['message']).to eq('Invalid login credentials.')
      end
    end
  end

  describe 'POST auth/sign_out' do
    context 'when not signed in' do
      it 'should return unauthorized error' do
        expect do
          post :sign_out

          expect(response).to have_http_status(:unauthorized)
          expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')
          parsed_response_body = JSON.parse(response.body)

          expect(parsed_response_body).to_not be_nil
          expect(parsed_response_body['error']).to_not be_nil
          expect(parsed_response_body['error']['message']).to eq('Invalid login credentials.')
        end.to change(Session, :count).by(0)
      end
    end

    context 'and user has an account version < 004' do
      it 'should return no response and no sessions should be deleted' do
        post :sign_in, params: test_user_credentials
        access_token = JSON.parse(response.body)['token']

        expect do
          request.headers['Authorization'] = "bearer #{access_token}"
          post :sign_out

          expect(response).to have_http_status(:no_content)
          parsed_response_body = JSON.parse(response.body)
          expect(parsed_response_body).to eq({})
        end.to change(Session, :count).by(0)
      end
    end

    context 'and user has an account version >= 004' do
      it 'should return no response and the session should be deleted' do
        post :sign_in, params: test_user_004_credentials
        access_token = JSON.parse(response.body)['token']

        expect do
          request.headers['Authorization'] = "bearer #{access_token}"
          post :sign_out

          expect(response).to have_http_status(:no_content)
          parsed_response_body = JSON.parse(response.body)
          expect(parsed_response_body).to eq({})
        end.to change(Session, :count).by(-1)
      end
    end
  end

  describe 'existing users authentication' do
    let(:existing_user) do
      build(:user, password: test_password)
    end

    before do
      user_manager = SyncEngine::V20200115::UserManager.new(User)
      sign_in_result = user_manager.sign_in(existing_user.email, test_password, '20200115', 'Fake UA')
      @jwt = sign_in_result[:token]      
    end 

    context 'when api_version is 20200115' do
      context 'and user version is <= 003' do
        context 'and a valid JWT is provided' do
          it 'should authenticate successfully' do
            expect(existing_user.version).to eq('003')

            @controller = Api::ItemsController.new
            request.headers['Authorization'] = "bearer #{@jwt}"

            new_item = { content: 'Test', content_type: 'Note' }
            post :create, params: { item: new_item, api_version: '20200115' }

            expect(response).to have_http_status(:ok)
            expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')
          end
        end
      end

      context 'and user version is >= 004' do
        context 'and a valid JWT is provided' do
          it 'should reject the request' do
            # Upgrading to new version 004
            user_manager = SyncEngine::V20200115::UserManager.new(User)
            change_pw_params = ActionController::Parameters.new(version: '004')
            user_manager.change_pw(existing_user, test_password, change_pw_params)
          
            test_user.reload
            expect(existing_user.version).to eq('004')

            # Authenticating with the above JWT
            @controller = Api::ItemsController.new
            request.headers['Authorization'] = "bearer #{@jwt}"

            new_item = { content: 'Test', content_type: 'Note' }
            post :create, params: { item: new_item, api_version: '20200115' }

            expect(response).to have_http_status(:unauthorized)
            expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')
          end
        end
      end
    end

    context 'when api_version is 20190520' do
      context 'and user version is <= 003' do
        context 'and a valid JWT is provided' do
          it 'should authenticate successfully' do
            expect(existing_user.version).to eq('003')

            @controller = Api::ItemsController.new
            request.headers['Authorization'] = "bearer #{@jwt}"

            new_item = { content: 'Test', content_type: 'Note' }
            post :create, params: { item: new_item, api_version: '20190520' }

            expect(response).to have_http_status(:ok)
            expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')
          end
        end
      end

      context 'and user version >= 004' do
        context 'and a valid JWT is provided' do
          it 'should reject the request' do
            # Upgrading to new version 004
            user_manager = SyncEngine::V20200115::UserManager.new(User)
            change_pw_params = ActionController::Parameters.new(version: '004')
            user_manager.change_pw(existing_user, test_password, change_pw_params)
          
            test_user.reload
            expect(existing_user.version).to eq('004')

            @controller = Api::ItemsController.new
            request.headers['Authorization'] = "bearer #{@jwt}"

            new_item = { content: 'Test', content_type: 'Note' }
            post :create, params: { item: new_item, api_version: '20190520' }

            expect(response).to have_http_status(:unauthorized)
            expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')
          end
        end
      end
    end
  end
end
