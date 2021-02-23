# DEPRECATED: Further development in https://github.com/standardnotes/syncing-server-js
class Api::ApiController < ApplicationController
  attr_accessor :current_user
  attr_accessor :current_session
  attr_accessor :user_manager

  EXPIRED_TOKEN_HTTP_CODE = 498

  before_action :authenticate_user

  before_action do
    request.env['HTTP_ACCEPT_ENCODING'] = 'gzip'
  end

  class InvalidApiVersion < StandardError
    def message
      'Invalid API version.'
    end
  end

  def token_from_request_header
    return unless request.headers['Authorization'].present?

    strategy, token = request.headers['Authorization'].split(' ')

    if !strategy || strategy.downcase != 'bearer'
      return
    end

    token
  end

  private

  def authenticate_user
    begin
      authenticated_via_proxy = authenticate_auth_service_proxy
    rescue StandardError => e
      Rails.logger.debug "Could not decode Auth token: #{e.message}"

      render_invalid_auth_error

      return
    end

    return if authenticated_via_proxy

    Rails.logger.debug 'Attempting authorization from Authorization Header.'

    authenticate_user_with_options(true)
  end

  def authenticate_auth_service_proxy
    return unless request.headers['X-Auth-Token'].present?

    Rails.logger.debug 'X-Auth-Token present in the request. Attempting authorization from JWT.'

    decoded_token = JWT.decode(request.headers['X-Auth-Token'], ENV['AUTH_JWT_SECRET'], true, algorithm: 'HS256')[0]

    self.current_user = User.find_by_uuid(decoded_token['user']['uuid'])
    if (decoded_token['session'])
      session = Session.find_by_uuid(decoded_token['session']['uuid'])
      unless session
        revoked_session = RevokedSession.find_by_uuid(decoded_token['session']['uuid'])
        render_revoked_session_error if revoked_session
      end
    end

    true
  end

  def authenticate_user_with_options(renders = true)
    token = token_from_request_header

    if token.nil?
      Rails.logger.debug 'No authentication token in the request header'

      render_invalid_auth_error if renders
      return
    end

    authentication = decode_token(token)

    if authentication.nil?
      Rails.logger.debug 'Could not decode authentication token'

      render_invalid_auth_error if renders
      return
    end

    if authentication[:type] == 'revoked'
      Rails.logger.debug 'Session has been revoked'

      render_revoked_session_error if renders
      return
    end

    user = authentication[:user]

    if user.nil?
      Rails.logger.debug 'No user in the decoded authentication token'

      render_invalid_auth_error if renders
      return
    end

    if authentication[:type] == 'jwt' && user.supports_sessions?
      Rails.logger.debug 'Passed JWT authentication but user supports sessions'

      render_invalid_auth_error if renders
      return
    end

    if authentication[:type] == 'session_token'
      if authentication[:session].refresh_expired?
        Rails.logger.debug 'Session refresh token expired'

        return render_invalid_auth_error if renders
      elsif authentication[:session].access_expired?
        Rails.logger.debug 'Session access token expired'

        return render_expired_token_error if renders
      end
    elsif authentication[:type] == 'jwt'
      pw_hash = authentication[:claims]['pw_hash']
      encrypted_password_digest = Digest::SHA256.hexdigest(user.encrypted_password)
      # Newer versions of our jwt include the user's hashed encrypted pw,
      # to check if the user has changed their pw and thus forbid them from access if they have an old jwt
      if !pw_hash || !ActiveSupport::SecurityUtils.secure_compare(pw_hash, encrypted_password_digest)
        Rails.logger.debug 'User has an old JWT'

        render_invalid_auth_error if renders
        return
      end
    end

    self.current_user = user
    self.current_session = authentication[:session]
  end

  def not_found(message = 'not_found')
    render json: { error: { message: message, tag: 'not-found' } }, status: :not_found
  end

  def render_invalid_auth_error
    render json: {
      error: {
        tag: 'invalid-auth',
        message: 'Invalid login credentials.',
      },
    }, status: :unauthorized
  end

  def render_revoked_session_error
    render json: {
      error: {
        tag: 'revoked-session',
        message: 'Your session has been revoked.',
      },
    }, status: :unauthorized
  end

  def render_expired_token_error
    render json: {
      error: {
        tag: 'expired-access-token',
        message: 'The provided access token has expired.',
      },
    }, status: EXPIRED_TOKEN_HTTP_CODE
  end

  def decode_token(token)
    Rails.logger.debug "Attempting to decode authorization token #{token}"

    claims = begin
              SyncEngine::JwtHelper.decode(token)
             rescue
               nil
            end

    return {
      type: 'jwt',
      user: User.find_by_uuid(claims['user_uuid']),
      claims: claims,
    } unless claims.nil?

    Rails.logger.debug 'Attempting to retrieve a session by access token'

    session = Session.from_token(token)

    if session
      return {
        type: 'session_token',
        user: session.user,
        session: session,
      }
    end

    revoked_session = RevokedSession.from_token(token)
    if revoked_session
      revoked_session.received = true
      revoked_session.save

      return {
        type: 'revoked',
        revoked_session: revoked_session,
      }
    end
  end
end
