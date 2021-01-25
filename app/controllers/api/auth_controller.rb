class Api::AuthController < Api::ApiController
  skip_before_action :authenticate_user, except: [:change_pw, :update]
  before_action :can_register, only: [:register]

  before_action do
    params[:user_agent] = request.user_agent

    # current_user can still be nil by here.
    user = User.find_by_email(params[:email])
    if user&.locked_until&.future?
      render json: {
        error: {
          message: 'Too many successive login requests. '\
            'Please try your request again later.',
        },
      }, status: :locked
    end

    @user_manager = user_manager
  end

  def mfa_for_email(email)
    user = User.find_by_email(email)
    return if user.nil?

    user.items.where(content_type: 'SF|MFA', deleted: false).first
  end

  # Returns true if the user does not have MFA enabled,
  # or if the supplied MFA parameters are valid
  def verify_mfa
    mfa = mfa_for_email(params[:email])
    return true if mfa.nil?

    mfa_content = mfa.decoded_content
    mfa_param_key = "mfa_#{mfa.uuid}"

    unless params[mfa_param_key]
      # Client needs to provide mfa value
      render json: {
        error: {
          tag: 'mfa-required',
          message: 'Please enter your two-factor authentication code.',
          payload: { mfa_key: mfa_param_key },
        },
      }, status: :unauthorized
      return false
    end

    # Client has provided mfa value
    received_code = params[mfa_param_key]
    totp = ROTP::TOTP.new(mfa_content['secret'])

    unless totp.verify(received_code)
      # Invalid MFA, abort login
      render json: {
        error: {
          tag: 'mfa-invalid',
          message: 'The two-factor authentication code you entered is incorrect. '\
            'Please try again.',
          payload: { mfa_key: mfa_param_key },
        },
      }, status: :unauthorized
      return false
    end

    true
  end

  def did_succeed_auth_attempt
    # current_user is only available to jwt requests (change_password)
    user = current_user || User.find_by_email(params[:email])
    user.locked_until = nil
    user.num_failed_attempts = 0
    user.save
  end

  def did_fail_auth_attempt
    # current_user is only available to jwt requests (change_password)
    user = current_user || User.find_by_email(params[:email])
    return unless user

    user.num_failed_attempts = 0 unless user.num_failed_attempts
    user.num_failed_attempts += 1
    if user.num_failed_attempts >= Rails.application.config.x.auth[:max_attempts_per_hour]
      user.num_failed_attempts = 0
      user.locked_until = DateTime.now + Rails.application.config.x.auth[:max_lockout].seconds
    end

    user.save
  end

  def sign_in
    Rails.logger.warn 'DEPRECATED: further development in https://github.com/standardnotes/syncing-server-js'

    unless verify_mfa
      return
    end

    if !params[:email] || !params[:password]
      return render_invalid_auth_error
    end

    result = @user_manager.sign_in(params[:email], params[:password], params)

    if result[:error]
      did_fail_auth_attempt
      render json: result, status: :unauthorized
    else
      did_succeed_auth_attempt
      render json: result
    end
  end

  def register
    Rails.logger.warn 'DEPRECATED: further development in https://github.com/standardnotes/syncing-server-js'

    if !params[:email] || !params[:password]
      render json: {
        error: {
          message: 'Please enter an email and a password to register.',
        },
      }, status: :unauthorized
      return
    end

    unless params[:version]
      params[:version] = params[:pw_nonce] ? '001' : '002'
    end

    result = @user_manager.register(params[:email], params[:password], params)

    if result[:error]
      render json: result, status: :unauthorized
      return
    end

    user = result[:user]
    user.updated_with_user_agent = request.user_agent
    user.save

    RegistrationJob.perform_later(user.email, user.created_at.to_s)

    render json: result
  end

  def change_pw
    Rails.logger.warn 'DEPRECATED: further development in https://github.com/standardnotes/syncing-server-js'

    unless params[:current_password]
      render json: {
        error: {
          message: 'Your current password is required to change your password. '\
            'Please update your application if you do not see this option.',
        },
      }, status: :unauthorized
      return
    end

    unless params[:new_password]
      render json: {
        error: {
          message: 'You new password is required to change your password. '\
            'Please try again.',
        },
      }, status: :unauthorized
      return
    end

    unless params[:pw_nonce]
      render json: {
        error: {
          message: 'The change password request is missing new auth parameters. '\
            'Please try again.',
        },
      }, status: :unauthorized
      return
    end

    # Verify current password first
    valid_credentials = @user_manager.verify_credentials(
      current_user.email,
      params[:current_password]
    )

    unless valid_credentials
      did_fail_auth_attempt

      render json: {
        error: {
          message: 'The current password you entered is incorrect. '\
            'Please try again.',
        },
      }, status: :unauthorized
      return
    end

    did_succeed_auth_attempt

    current_user.updated_with_user_agent = request.user_agent
    result = @user_manager.change_pw(current_user, current_session, params[:new_password], params)

    if result[:error]
      render json: result, status: :unauthorized
    else
      render json: result
    end
  end

  # Presently not used by clients, but used by tests.
  # Will be used by clients starting with client v4+
  def update
    Rails.logger.warn 'DEPRECATED: further development in https://github.com/standardnotes/syncing-server-js'

    current_user.updated_with_user_agent = request.user_agent
    result = @user_manager.update(current_user, params)
    if result[:error]
      render json: result, status: :unauthorized
    else
      render json: result
    end
  end

  # Returns the accounts key parameters (FKA auth_params).
  # If the account has MFA enabled, those parameters will be required.
  def auth_params
    Rails.logger.warn 'DEPRECATED: further development in https://github.com/standardnotes/syncing-server-js'

    authenticate_user_with_options(false)

    # If the user is authenticated, we return additional parameters
    has_session = !current_session.nil?
    if has_session
      render json: current_user.key_params(true)
      return
    end

    unless verify_mfa
      return
    end

    unless params[:email]
      render json: {
        error: {
          message: 'Please provide an email address.',
        },
      }, status: :bad_request
      return
    end

    auth_params = User.find_by_email(params[:email])&.key_params

    unless auth_params
      render json: pseudo_auth_params(params[:email])
      return
    end

    render json: auth_params
  end

  # When looking up emails for accounts that do not exist,
  # send psuedo parameters to mask existence status of account
  def pseudo_auth_params(email)
    {
      identifier: email,
      pw_nonce: Digest::SHA2.hexdigest(email + ENV['PSEUDO_KEY_PARAMS_KEY']),
      version: '004',
    }.sort.to_h
  end

  def sign_out
    Rails.logger.warn 'DEPRECATED: further development in https://github.com/standardnotes/syncing-server-js'

    # Users with an expired token may still make a request to the sign out endpoint
    token = token_from_request_header

    if token.nil?
      render_invalid_auth_error
      return
    end

    session = Session.from_token(token)
    session&.destroy
    render json: {}, status: :no_content
  end

  private

  def can_register
    registration_disabled = ENV['DISABLE_USER_REGISTRATION'].to_s.downcase == 'true'

    if registration_disabled
      render json: {
        error: {
          message: 'User registration is currently not allowed.',
        },
      }, status: :unauthorized
    end
  end

  def user_manager
    version = params[:api]

    # If no version is present, this implies an older client version.
    # In this case, the oldest API version should be used.
    unless version
      return SyncEngine::V20161215::UserManager.new(User)
    end

    # All other clients should specify a valid API version.
    case version
    when '20200115'
      SyncEngine::V20200115::UserManager.new(User)
    when '20190520'
      SyncEngine::V20190520::UserManager.new(User)
    else
      raise InvalidApiVersion
    end
  end
end
