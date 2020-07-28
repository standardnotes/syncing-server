class Api::ApiController < ApplicationController
  respond_to :json

  attr_accessor :current_user
  attr_accessor :current_session
  attr_accessor :user_manager

  before_action :authenticate_user
  before_action :set_raven_context

  before_action do
    request.env['HTTP_ACCEPT_ENCODING'] = 'gzip'
  end

  class InvalidApiVersion < StandardError
    def message
      'Invalid API version.'
    end
  end

  private

  def authenticate_user
    token = token_from_request_header

    if token.nil?
      render_invalid_auth_error
      return
    end

    authentication = validate_token token

    if authentication.nil?
      render_invalid_auth_error
      return
    end

    user = user_from_authentication authentication

    if user.nil?
      render_invalid_auth_error
      return
    end

    if authentication[:type] == 'jwt' && params[:api].to_i >= 20190520 && user.supports_sessions?
      render_invalid_auth_error
      return
    end

    if authentication[:type] == 'session_token' && authentication[:session].expired?
      render_invalid_auth_error
      return
    end

    if authentication[:type] == 'session_token' && authentication[:session].expired_access_token?
      render_expired_token_error
      return
    end

    if authentication[:type] == 'jwt'
      pw_hash = authentication[:claims]['pw_hash']
      encrypted_password_digest = Digest::SHA256.hexdigest(user.encrypted_password)
      # newer versions of our jwt include the user's hashed encrypted pw,
      # to check if the user has changed their pw and thus forbid them from access if they have an old jwt
      unless ActiveSupport::SecurityUtils.secure_compare(pw_hash, encrypted_password_digest)
        render_invalid_auth_error
        return
      end
    end

    self.current_user = user
    self.current_session = authentication[:session] if authentication[:type] == 'session_token'
  end

  # Used especially for when the session is expired and the client makes a sign out request,
  # we want to be able to authenticate the user, so we can terminate the session.
  def authenticate_user_for_sign_out
    token = token_from_request_header

    if token.nil?
      render_invalid_auth_error
      return
    end

    authentication = validate_token token

    if authentication.nil?
      return
    end

    user = user_from_authentication authentication

    if user.nil?
      return
    end

    if authentication[:type] == 'jwt'
      return
    end

    self.current_user = user
    self.current_session = authentication[:session]
  end

  def set_raven_context
    if current_user
      Raven.user_context(id: current_user.uuid)
    end

    Raven.extra_context(params: params.to_unsafe_h, url: request.url)
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
    }, status: :expired_access_token
  end

  def token_from_request_header
    unless request.headers['Authorization'].present?
      return
    end

    strategy, token = request.headers['Authorization'].split(' ')

    if (strategy || '').downcase != 'bearer'
      return
    end

    token
  end

  def user_from_authentication(authentication)
    return authentication[:session].user unless authentication[:session].nil?

    User.find_by_uuid authentication[:user_uuid]
  end

  def validate_token(token)
    # Try JWT first...
    claims = begin
              SyncEngine::JwtHelper.decode(token)
             rescue
               nil
            end

    return { type: 'jwt', user_uuid: claims['user_uuid'], claims: claims } unless claims.nil?

    # See if it's an access_token...
    session = Session.where(access_token: token).first

    if session && ActiveSupport::SecurityUtils.secure_compare(token, session.access_token)
      { type: 'session_token', user_uuid: session.user_uuid, session: session }
    end
  end
end
