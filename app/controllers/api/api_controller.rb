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
    authenticate_user_with_options(true)
  end

  def authenticate_user_with_options(renders = true)
    token = token_from_request_header

    if token.nil?
      render_invalid_auth_error if renders
      return
    end

    authentication = decode_token(token)

    if authentication.nil?
      render_invalid_auth_error if renders
      return
    end

    user = authentication[:user]

    if user.nil?
      render_invalid_auth_error if renders
      return
    end

    if authentication[:type] == 'jwt' && user.supports_sessions?
      render_invalid_auth_error if renders
      return
    end

    if authentication[:type] == 'session_token'
      if authentication[:session].refresh_expired?
        return render_invalid_auth_error if renders
      elsif authentication[:session].access_expired?
        return render_expired_token_error if renders
      end
    elsif authentication[:type] == 'jwt'
      pw_hash = authentication[:claims]['pw_hash']
      encrypted_password_digest = Digest::SHA256.hexdigest(user.encrypted_password)
      # Newer versions of our jwt include the user's hashed encrypted pw,
      # to check if the user has changed their pw and thus forbid them from access if they have an old jwt
      if !pw_hash || !ActiveSupport::SecurityUtils.secure_compare(pw_hash, encrypted_password_digest)
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

  def render_expired_token_error
    render json: {
      error: {
        tag: 'expired-access-token',
        message: 'The provided access token has expired.',
      },
    }, status: EXPIRED_TOKEN_HTTP_CODE
  end

  def decode_token(token)
    # Try JWT first
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

    # See if it's an access_token
    session = Session.from_token(token)

    if session
      return {
        type: 'session_token',
        user: session.user,
        session: session,
      }
    end
  end
end
