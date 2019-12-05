class Api::AuthController < Api::ApiController

  skip_before_action :authenticate_user, except: [:change_pw, :update]

  before_action do
    # current_user can still be nil by here.
    user = User.find_by_email(params[:email])
    if user && user.locked_until && user.locked_until.future?
      render :json => {error: {message: "Too many successive login requests. Please try your request again later."}}, :status => 423
    end
    @user_manager = user_manager
  end

  def mfa_for_email(email)
    user = User.find_by_email(email)
    return if user == nil
    mfa = user.items.where("content_type" => "SF|MFA", "deleted" => false).first
    return mfa
  end

  def verify_mfa(email)
    mfa = mfa_for_email(params[:email])

    if mfa != nil
      mfa_content = mfa.decoded_content
      mfa_param_key = "mfa_#{mfa.uuid}"
      if params[mfa_param_key]
        # Client has provided mfa value
        received_code = params[mfa_param_key]
        totp = ROTP::TOTP.new(mfa_content["secret"])
        if !totp.verify(received_code)
          # Invalid MFA, abort login
          render :json => {
              :error => {
                :tag => "mfa-invalid",
                :message => "The two-factor authentication code you entered is incorrect. Please try again.",
                :payload => {:mfa_key => mfa_param_key}
              }
            }, :status => 401
            return false
        end
      else
        # Client needs to provide mfa value
        render :json => {
            :error => {
              :tag => "mfa-required",
              :message => "Please enter your two-factor authentication code.",
              :payload => {:mfa_key => mfa_param_key}
            }
          }, :status => 401
        return false
      end
    else
      # mfa is nil
      return true
    end
  end

  def handle_successful_auth_attempt
    # current_user is only available to jwt requests (change_password)
    user = current_user || User.find_by_email(params[:email])
    user.locked_until = nil
    user.num_failed_attempts = 0
    user.save
  end

  MAX_LOCKOUT = 3600 # 1 Hour
  MAX_ATTEMPTS = 6 # Per hour
  def handle_failed_auth_attempt
    # current_user is only available to jwt requests (change_password)
    user = current_user || User.find_by_email(params[:email])
    return if !user

    user.num_failed_attempts = 0 if !user.num_failed_attempts
    user.num_failed_attempts += 1
    if user.num_failed_attempts >= MAX_ATTEMPTS
      user.num_failed_attempts = 0
      user.locked_until = DateTime.now + MAX_LOCKOUT.seconds
    end

    user.save
  end

  def sign_in
    if verify_mfa(params[:email]) == false
      # error responses are handled by the verify_mfa method
      return
    end

    result = @user_manager.sign_in(params[:email], params[:password])
    if result[:error]
      self.handle_failed_auth_attempt
      render :json => result, :status => 401
    else
      self.handle_successful_auth_attempt
      render :json => result
    end
  end

  def register
    if !params[:version]
      params[:version] = "002"
    end

    result = @user_manager.register(params[:email], params[:password], params)
    if result[:error]
      render :json => result, :status => 401
    else
      user = result[:user]
      user.updated_with_user_agent = request.user_agent
      user.save
      unless ENV['SYNCING_SERVER_EDITION'] == 'community'
        RegistrationJob.perform_later(user.email, user.created_at.to_s)
      end
      render :json => result
    end
  end

  def change_pw
    if !params[:current_password]
      render :json => {:error => {:message => "Your current password is required to change your password. Please update your application if you do not see this option."}}, :status => 401
      return
    end

    if !params[:pw_nonce]
      render :json => {:error => {:message => "The change password request is missing new auth parameters. Please try again."}}, :status => 401
      return
    end

    # Verify current password first
    sign_in_result = @user_manager.sign_in(current_user.email, params[:current_password])
    if sign_in_result[:error]
      self.handle_failed_auth_attempt
      render :json => {:error => {:message => "The current password you entered is incorrect. Please try again."}}, :status => 401
      return
    end

    self.handle_successful_auth_attempt

    current_user.updated_with_user_agent = request.user_agent

    result = @user_manager.change_pw(current_user, params[:new_password], params)
    if result[:error]
      render :json => result, :status => 401
    else
      render :json => result
    end
  end

  def update
    current_user.updated_with_user_agent = request.user_agent
    result = @user_manager.update(current_user, params)
    if result[:error]
      render :json => result, :status => 401
    else
      render :json => result
    end
  end

  def auth_params
    if verify_mfa(params[:email]) == false
      # error responses are handled by the verify_mfa method
      return
    end

    auth_params = @user_manager.auth_params(params[:email])
    if !auth_params
      render :json => self.pseudo_auth_params(params[:email])
    else
      render :json => @user_manager.auth_params(params[:email])
    end
  end

  def pseudo_auth_params(email)
    return {
      identifier: email,
      pw_cost: 110000,
      pw_nonce: Digest::SHA2.hexdigest(email + ENV['SECRET_KEY_BASE']),
      version: "003"
    }
  end

end
