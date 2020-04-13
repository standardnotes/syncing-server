class Api::AuthController < Api::ApiController
  skip_before_action :authenticate_user, except: [:change_pw, :update, :sign_out]

  before_action do
    # current_user can still be nil by here.
    user = User.find_by_email(params[:email])
    if user&.locked_until&.future?
      render json: {
        error: {
          message: 'Too many successive login requests. '\
            'Please try your request again later.',
        },
      }, status: 423
    end
    @user_manager = user_manager
  end

  def mfa_for_email(email)
    user = User.find_by_email(email)
    return if user.nil?

    user.items.where(content_type: 'SF|MFA', deleted: false).first
  end

  def verify_mfa
    mfa = mfa_for_email(params[:email])

    if mfa.nil?
      return true
    end

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
      }, status: 401

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
      }, status: 401

      false
    end
  end

  def handle_successful_auth_attempt
    # current_user is only available to jwt requests (change_password)
    user = current_user || User.find_by_email(params[:email])
    user.locked_until = nil
    user.num_failed_attempts = 0
    user.save
  end

  def handle_failed_auth_attempt
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
    if verify_mfa == false
      # error responses are handled by the verify_mfa method
      return
    end

    if !params[:email] || !params[:password]
      return render_invalid_auth
    end

    result = @user_manager.sign_in(params[:email], params[:password], params[:api_version], request.user_agent)
    if result[:error]
      handle_failed_auth_attempt
      render json: result, status: 401
    else
      handle_successful_auth_attempt
      render json: result
    end
  end

  def register
    if !params[:email] || !params[:password]
      return render json: {
        error: {
          message: 'Please enter an email and a password to register.',
        },
      }, status: 401
    end

    unless params[:version]
      params[:version] = '002'
    end

    result = @user_manager.register(params[:email], params[:password], params, request.user_agent)
    if result[:error]
      render json: result, status: 401
    else
      user = result[:user]
      user.updated_with_user_agent = request.user_agent
      user.save
      if ENV['AWS_REGION']
        RegistrationJob.perform_later(user.email, user.created_at.to_s)
      end
      render json: result
    end
  end

  def change_pw
    unless params[:current_password]
      render json: {
        error: {
          message: 'Your current password is required to change your password. '\
            'Please update your application if you do not see this option.',
        },
      }, status: 401

      return
    end

    unless params[:pw_nonce]
      render json: {
        error: {
          message: 'The change password request is missing new auth parameters. '\
            'Please try again.',
        },
      }, status: 401

      return
    end

    # Verify current password first
    valid_credentials = @user_manager.verify_credentials(current_user.email, params[:current_password])
    unless valid_credentials
      handle_failed_auth_attempt
      render json: {
        error: {
          message: 'The current password you entered is incorrect. '\
            'Please try again.',
        },
      }, status: 401

      return
    end

    handle_successful_auth_attempt

    current_user.updated_with_user_agent = request.user_agent

    result = @user_manager.change_pw(current_user, params[:new_password], params)
    if result[:error]
      render json: result, status: 401
    else
      render json: result
    end
  end

  def update
    current_user.updated_with_user_agent = request.user_agent
    result = @user_manager.update(current_user, params)
    if result[:error]
      render json: result, status: 401
    else
      render json: result
    end
  end

  def auth_params
    if verify_mfa == false
      # error responses are handled by the verify_mfa method
      return
    end

    auth_params = @user_manager.auth_params(params[:email])
    if !auth_params
      render json: pseudo_auth_params(params[:email])
    else
      render json: @user_manager.auth_params(params[:email])
    end
  end

  def pseudo_auth_params(email)
    {
      identifier: email,
      pw_cost: 110000,
      pw_nonce: Digest::SHA2.hexdigest(email + Rails.application.secrets.secret_key_base),
      version: '003',
    }
  end

  def sign_out
    current_session&.destroy

    render json: {}, status: :no_content
  end
end
