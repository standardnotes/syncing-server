class Api::ApiController < ApplicationController
  respond_to :json

  attr_accessor :current_user
  attr_accessor :user_manager

  before_action :authenticate_user
  before_action :set_raven_context

  before_action do
    request.env['HTTP_ACCEPT_ENCODING'] = 'gzip'
    self.user_manager = SyncEngine::V20190520::UserManager.new(User)
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

    claims = begin
               SyncEngine::JwtHelper.decode(token)
             rescue
               nil
             end
    user = User.find_by_uuid claims['user_uuid'] unless claims.nil?

    if user.nil?
      render_invalid_auth
      return
    end

    # If a user signed in before the JWT change was made below, they won't have a pw_hash.
    if claims['pw_hash']
      encrypted_password_digest = Digest::SHA256.hexdigest(user.encrypted_password)
      # newer versions of our jwt include the user's hashed encrypted pw,
      # to check if the user has changed their pw and thus forbid them from access if they have an old jwt
      if ActiveSupport::SecurityUtils.secure_compare(claims['pw_hash'], encrypted_password_digest) == false
        render_invalid_auth
        return
      end
    end

    self.current_user = user
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
    render json: { error: { tag: 'invalid-auth', message: 'Invalid login credentials.' } }, status: 401
  end
end
