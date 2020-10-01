module SyncEngine
  class AbstractUserManager
    def initialize(user_class)
      @user_class = user_class
    end

    def registration_fields
      [:pw_func, :pw_alg, :pw_cost, :pw_key_size, :pw_nonce, :pw_salt, :origination, :created, :version]
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

    private

    def success_auth_response(_user, _params)
      raise Other::NotImplementedError 'Must override'
    end

    def registration_params(params, with_defaults = true)
      defaults = {
        pw_func: nil,
        pw_alg: nil,
        pw_cost: nil,
        pw_salt: nil,
        pw_key_size: nil,
      }

      if with_defaults
        return params.permit(*registration_fields).reverse_merge(defaults)
      end

      params.permit(*registration_fields)
    end
  end
end
