module SyncEngine
  class AbstractUserManager
    def initialize(user_class)
      @user_class = user_class
    end

    def verify_credentials(email, password)
      user = @user_class.find_by_email(email)
      user && test_password(password, user.encrypted_password)
    end

    def sign_in(email, password, params)
      user = @user_class.find_by_email(email)
      if verify_credentials(email, password)
        return success_auth_response(user, params)
      else
        return { error: { message: 'Invalid email or password.', status: 401 } }
      end
    end

    def register(email, password, params)
      user = @user_class.find_by_email(email)
      if user
        return { error: { message: 'This email is already registered.', status: 401 } }
      else
        user = @user_class.new(email: email, encrypted_password: hash_password(password))
        user.update!(registration_params(params))
        return success_auth_response(user, params)
      end
    end

    def change_pw(user, _session, password, params)
      user.encrypted_password = hash_password(password)
      user.update!(registration_params(params))
      return success_auth_response(user, params)
    end

    def update(user, params)
      user.update!(registration_params(params))
      return success_auth_response(user, params)
    end

    def auth_params(email)
      user = @user_class.find_by_email(email)
      return nil unless user

      auth_params = {
        identifier: user.email,
        pw_cost: user.pw_cost,
        pw_nonce: user.pw_nonce,
        version: user.version,
      }

      if user.version == '002'
        auth_params[:pw_salt] = user.pw_salt
      end

      if user.version == '001'
        auth_params[:pw_func] = user.pw_func
        auth_params[:pw_alg] = user.pw_alg
        auth_params[:pw_key_size] = user.pw_key_size
      end

      return auth_params
    end

    private

    def success_auth_response(_user, _params)
      raise Other::NotImplementedError 'Must override'
    end

    def registration_params(params)
      params.permit(
        :pw_func,
        :pw_alg,
        :pw_cost,
        :pw_key_size,
        :pw_nonce,
        :pw_salt,
        :version
      )
    end
  end
end
