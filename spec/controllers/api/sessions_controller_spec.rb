require 'rails_helper'

RSpec.describe Api::SessionsController, type: :controller do
  test_password = '123456'

  let(:test_user_003) do
    build(:user, password: test_password)
  end

  let(:test_user_004) do
    build(:user, password: test_password, version: '004')
  end

  let(:test_user_003_credentials) do
    { email: test_user_003.email, password: test_password }
  end

  let(:test_user_004_credentials) do
    { email: test_user_004.email, password: test_password, api: '20200115' }
  end

  describe 'GET sessions/active' do
    context 'when not signed in' do
      it 'should return unauthorized error' do
        get :index

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
      context 'and user has an account version < 004' do
        it 'should return unsupported error' do
          @controller = Api::AuthController.new
          post :sign_in, params: test_user_003_credentials

          @controller = Api::SessionsController.new
          request.headers['Authorization'] = "bearer #{JSON.parse(response.body)['token']}"

          get :index

          expect(response).to have_http_status(:bad_request)
          expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')

          parsed_response_body = JSON.parse(response.body)

          expect(parsed_response_body).to_not be_nil
          expect(parsed_response_body['error']).to_not be_nil
          expect(parsed_response_body['error']['message']).to eq('Account version not supported.')
          expect(parsed_response_body['error']['tag']).to eq('unsupported-account-version')
        end
      end

      context 'and user has an account version >= 004' do
        it 'should return all active sessions' do
          @controller = Api::AuthController.new
          post :sign_in, params: test_user_004_credentials

          @controller = Api::SessionsController.new
          request.headers['Authorization'] = "bearer #{JSON.parse(response.body)['token']}"

          get :index

          expect(response).to have_http_status(:ok)
          expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')

          parsed_response_body = JSON.parse(response.body)

          expect(parsed_response_body).to_not be_nil

          # It should contain the current session
          expect(parsed_response_body.any? { |session| session['current'] == true }).to be_truthy
        end
      end
    end
  end

  describe 'DELETE session' do
    context 'when not signed in' do
      it 'should return unauthorized error' do
        delete :delete

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
      context 'and user has an account version < 004' do
        it 'should return unsupported error' do
          @controller = Api::AuthController.new
          post :sign_in, params: test_user_003_credentials

          @controller = Api::SessionsController.new
          request.headers['Authorization'] = "bearer #{JSON.parse(response.body)['token']}"

          delete :delete

          expect(response).to have_http_status(:bad_request)
          expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')

          parsed_response_body = JSON.parse(response.body)

          expect(parsed_response_body).to_not be_nil
          expect(parsed_response_body['error']).to_not be_nil
          expect(parsed_response_body['error']['message']).to eq('Account version not supported.')
          expect(parsed_response_body['error']['tag']).to eq('unsupported-account-version')
        end
      end

      context 'and user has an account version >= 004' do
        context 'and no uuid param was provided' do
          it 'should fail' do
            @controller = Api::AuthController.new
            post :sign_in, params: test_user_004_credentials

            @controller = Api::SessionsController.new
            request.headers['Authorization'] = "bearer #{JSON.parse(response.body)['token']}"

            delete :delete

            expect(response).to have_http_status(:bad_request)
            expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')

            parsed_response_body = JSON.parse(response.body)

            expect(parsed_response_body).to_not be_nil
            expect(parsed_response_body['error']).to_not be_nil
            expect(parsed_response_body['error']['message']).to eq('Please provide the session identifier.')
          end
        end

        context 'and the current session uuid was provided' do
          it 'should fail' do
            @controller = Api::AuthController.new
            post :sign_in, params: test_user_004_credentials

            @controller = Api::SessionsController.new
            access_token = JSON.parse(response.body)['token']
            request.headers['Authorization'] = "bearer #{access_token}"
            current_session = test_user_004.sessions.where(access_token: access_token).first

            delete :delete, params: { uuid: current_session.uuid }

            expect(response).to have_http_status(:bad_request)
            expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')

            parsed_response_body = JSON.parse(response.body)

            expect(parsed_response_body).to_not be_nil
            expect(parsed_response_body['error']).to_not be_nil
            expect(parsed_response_body['error']['message']).to eq('You can not delete your current session.')
          end
        end

        context 'and a session uuid from another user was provided' do
          it 'should fail and no records should be deleted' do
            @controller = Api::AuthController.new
            post :sign_in, params: test_user_004_credentials

            @controller = Api::SessionsController.new
            access_token = JSON.parse(response.body)['token']
            request.headers['Authorization'] = "bearer #{access_token}"

            another_test_user = build(:user, password: test_password, version: '004')
            other_session = another_test_user.sessions.first

            expect do
              delete :delete, params: { uuid: other_session.uuid }

              expect(response).to have_http_status(:bad_request)
              expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')

              parsed_response_body = JSON.parse(response.body)

              expect(parsed_response_body).to_not be_nil
              expect(parsed_response_body['error']).to_not be_nil
              expect(parsed_response_body['error']['message']).to eq('No session exists with the provided identifier.')
            end.to change(Session, :count).by(0)
          end
        end

        context 'and a valid uuid param was provided' do
          it 'should succeed' do
            @controller = Api::AuthController.new
            post :sign_in, params: test_user_004_credentials

            @controller = Api::SessionsController.new
            access_token = JSON.parse(response.body)['token']
            request.headers['Authorization'] = "bearer #{access_token}"
            other_session = test_user_004.sessions.where.not(access_token: access_token).first

            expect do
              delete :delete, params: { uuid: other_session.uuid }

              expect(response).to have_http_status(:no_content)
              parsed_response_body = JSON.parse(response.body)
              expect(parsed_response_body).to eq({})
            end.to change(Session, :count).by(-1)
          end
        end
      end
    end
  end

  describe 'DELETE session/all' do
    context 'when not signed in' do
      it 'should return unauthorized error' do
        delete :delete_all

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
      context 'and user has an account version < 004' do
        it 'should return unsupported error' do
          @controller = Api::AuthController.new
          post :sign_in, params: test_user_003_credentials

          @controller = Api::SessionsController.new
          request.headers['Authorization'] = "bearer #{JSON.parse(response.body)['token']}"

          delete :delete_all

          expect(response).to have_http_status(:bad_request)
          expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')

          parsed_response_body = JSON.parse(response.body)

          expect(parsed_response_body).to_not be_nil
          expect(parsed_response_body['error']).to_not be_nil
          expect(parsed_response_body['error']['message']).to eq('Account version not supported.')
          expect(parsed_response_body['error']['tag']).to eq('unsupported-account-version')
        end
      end

      context 'and user has an account version >= 004' do
        it 'should succeed and delete all sessions except the current one' do
          @controller = Api::AuthController.new
          post :sign_in, params: test_user_004_credentials

          @controller = Api::SessionsController.new
          access_token = JSON.parse(response.body)['token']
          request.headers['Authorization'] = "bearer #{access_token}"

          # Registering another test user, so multiple sessions from multiple users exist...
          build(:user, password: test_password, version: '004')

          current_user_sessions = test_user_004.sessions

          expect do
            delete :delete_all

            expect(response).to have_http_status(:no_content)
            parsed_response_body = JSON.parse(response.body)
            expect(parsed_response_body).to eq({})
          end.to change(Session, :count).by(-(current_user_sessions.count - 1))
        end
      end
    end
  end

  describe 'POST session/refresh' do
    context 'with missing parameters' do
      it 'should fail' do
        post :refresh

        expect(response).to have_http_status(:bad_request)
        expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')

        parsed_response_body = JSON.parse(response.body)

        expect(parsed_response_body).to_not be_nil
        expect(parsed_response_body['error']).to_not be_nil
        expect(parsed_response_body['error']['message']).to eq('Please provide all required parameters.')
      end
    end

    context 'with invalid parameters' do
      it 'should fail' do
        post :refresh, params: {
          user_uuid: 'not-a-real-uuid',
          access_token: 'not-a-real-access-token',
          refresh_token: 'not-a-real-refresh-token',
        }

        expect(response).to have_http_status(:bad_request)
        expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')

        parsed_response_body = JSON.parse(response.body)

        expect(parsed_response_body).to_not be_nil
        expect(parsed_response_body['error']).to_not be_nil
        expect(parsed_response_body['error']['message']).to eq('The provided parameters are not valid.')
        expect(parsed_response_body['error']['tag']).to eq('invalid-parameters')
      end
    end

    context 'with an expired refresh token' do
      it 'should fail' do
        @controller = Api::AuthController.new
        post :sign_in, params: test_user_004_credentials

        @controller = Api::SessionsController.new
        access_token = JSON.parse(response.body)['token']

        # Expiring the refresh token...
        current_session = test_user_004.sessions.where(access_token: access_token).first
        current_session.expire_at = DateTime.now - 3600.seconds
        current_session.save

        refresh_token = current_session.refresh_token

        expect do
          post :refresh, params: {
            user_uuid: test_user_004.uuid,
            access_token: access_token,
            refresh_token: refresh_token,
          }

          expect(response).to have_http_status(:bad_request)
          expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')

          parsed_response_body = JSON.parse(response.body)

          expect(parsed_response_body).to_not be_nil
          expect(parsed_response_body['error']).to_not be_nil
          expect(parsed_response_body['error']['message']).to eq('The refresh token has expired.')
          expect(parsed_response_body['error']['tag']).to eq('expired-refresh-token')
        end.to change(Session, :count).by(0)

        # Tokens should remain the same...
        expect(current_session.access_token).to eq(access_token)
        expect(current_session.refresh_token).to eq(refresh_token)

        # Session should remain expired...
        current_session.reload
        expect(current_session.expire_at).to be < DateTime.now
      end
    end

    context 'with a valid refresh token' do
      it 'should succeed' do
        @controller = Api::AuthController.new
        post :sign_in, params: test_user_004_credentials

        @controller = Api::SessionsController.new
        access_token = JSON.parse(response.body)['token']

        current_session = test_user_004.sessions.where(access_token: access_token).first
        refresh_token = current_session.refresh_token

        expect do
          post :refresh, params: {
            access_token: access_token,
            refresh_token: refresh_token,
          }

          expect(response).to have_http_status(:ok)
          expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')

          parsed_response_body = JSON.parse(response.body)

          expect(parsed_response_body).to_not be_nil
          expect(parsed_response_body['token']).to_not be_nil
          expect(parsed_response_body['token']).to_not eq(access_token)

          expect(parsed_response_body['session']).to_not be_nil
          expect(parsed_response_body['session']['expire_at']).to_not be_nil
          expect(parsed_response_body['session']['expire_at']).to be_an(Numeric)
          expect(parsed_response_body['session']['expire_at']).to be > 0

          expect(parsed_response_body['session']['refresh_token']).to_not be_nil
          expect(parsed_response_body['session']['refresh_token']).to_not eq(access_token)
        end.to change(Session, :count).by(0)

        # Tokens should be renewed...
        current_session.reload
        expect(current_session.access_token).to_not eq(access_token)
        expect(current_session.refresh_token).to_not eq(refresh_token)
      end
    end
  end
end
