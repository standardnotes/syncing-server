module SyncEngine
  module V20200115
    class UserManager < SyncEngine::V20190520::UserManager
      def change_pw(user, session, password, params)
        current_protocol_version = user.version.to_i
        new_protocol_version = params[:version].to_i || current_protocol_version
        upgrading_protocol_version = new_protocol_version > current_protocol_version

        user.encrypted_password = hash_password(password)
        user.update!(registration_params(params, true))

        tokens = Session.generate_tokens

        if upgrading_protocol_version && new_protocol_version == @user_class::SESSIONS_PROTOCOL_VERSION
          session = create_session(user, params, tokens)
        end

        return {
          session: session&.as_client_payload(tokens[:access_token], tokens[:refresh_token]),
          key_params: user.key_params(true),
          user: user,
        }
      end

      private

      def success_auth_response(user, params)
        unless user.supports_sessions?
          return super(user, params)
        end

        tokens = Session.generate_tokens
        session = create_session(user, params, tokens)

        unless session
          return {
            error: {
              message: 'Could not create a session.',
              status: 400,
            },
          }
        end

        return {
          session: session.as_client_payload(tokens[:access_token], tokens[:refresh_token]),
          key_params: user.key_params(true),
          user: user,
        }
      end

      def create_session(user, params, tokens)
        session = user.sessions.new(
          api_version: params[:api],
          user_agent: params[:user_agent]
        )

        session.set_hashed_tokens(tokens[:access_token], tokens[:refresh_token])

        return nil unless session.save

        return session
      end

      deprecate :update
    end
  end
end
