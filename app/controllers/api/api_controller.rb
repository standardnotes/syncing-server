class Api::ApiController < ApplicationController
  respond_to :json

  attr_accessor :current_user
  attr_accessor :current_session
  attr_accessor :user_manager

  before_action :authenticate_user
  before_action :set_raven_context

  before_action do
    request.env['HTTP_ACCEPT_ENCODING'] = 'gzip'
    self.user_manager = SyncEngine::V20200115::UserManager.new(User)
  end

  protected

  def authenticate_user
    unless request.headers['Authorization'].present?
      render_invalid_auth
      return
    end

    strategy, token = request.headers['Authorization'].split(' ')
    if (strategy || '').downcase != 'bearer'
      render_invalid_auth
      return
    end

    authentication = validate_token token

    if authentication.nil?
      render_invalid_auth
      return
    end

    user = User.find_by_uuid authentication[:user_uuid]

    if user.nil?
      render_invalid_auth
      return
    end

    if authentication[:type] == 'jwt' && params[:api].to_i >= 20190520 && user.supports_sessions?
      render_invalid_auth
      return
    end

    if authentication[:type] == 'session_token' && authentication[:session].expired_access_token?
      render json: {
        error: {
          tag: 'expired-access-token',
          message: 'The provided access token has expired.',
        },
      }, status: :unauthorized

      return
    end

    # If a user signed in before the JWT change was made below, they won't have a pw_hash.
    if authentication[:type] == 'jwt' && authentication[:claims]['pw_hash']
      pw_hash = authentication[:claims]['pw_hash']
      encrypted_password_digest = Digest::SHA256.hexdigest(user.encrypted_password)
      # newer versions of our jwt include the user's hashed encrypted pw,
      # to check if the user has changed their pw and thus forbid them from access if they have an old jwt
      unless ActiveSupport::SecurityUtils.secure_compare(pw_hash, encrypted_password_digest)
        render_invalid_auth
        return
      end
    end

    self.current_user = user
    self.current_session = authentication[:session] if authentication[:type] == 'session_token'
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

  def render_invalid_auth
    render json: { error: { tag: 'invalid-auth', message: 'Invalid login credentials.' } }, status: :unauthorized
  end

  private

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
