module SyncEngine
  class AbstractUserManager
    def initialize(user_class)
      @user_class = user_class
    end

    def verify_credentials(email, password)
      user = @user_class.find_by_email(email)
      user && test_password(password, user.encrypted_password)
    end

    def sign_in(email, password, api_version, user_agent)
      user = @user_class.find_by_email(email)
      if verify_credentials(email, password)
        create_session(user, api_version, user_agent)
      else
        { error: { message: 'Invalid email or password.', status: 401 } }
      end
    end

    def register(email, password, params, user_agent = '')
      user = @user_class.find_by_email(email)
      if user
        { error: { message: 'This email is already registered.', status: 401 } }
      else
        user = @user_class.new(email: email, encrypted_password: hash_password(password))
        user.update!(registration_params(params))
        create_session(user, params[:api_version], user_agent)
      end
    end

    def change_pw(user, password, params)
      user.encrypted_password = hash_password(password)
      user.update!(registration_params(params))

      result = { user: user }

      if user.supports_jwt?
        result[:token] = jwt(user)
      end

      result
    end

    def update(user, params)
      user.update!(registration_params(params))

      result = { user: user }

      if user.supports_jwt?
        result[:token] = jwt(user)
      end

      result
    end

    def auth_params(email)
      user = @user_class.find_by_email(email)

      unless user
        return nil
      end

      auth_params = {
        identifier: user.email,
        pw_cost: user.pw_cost,
        pw_nonce: user.pw_nonce,
        version: user.version,
      }

      if user.pw_salt
        # v002 only
        auth_params[:pw_salt] = user.pw_salt
      end

      if user.pw_func
        # v001 only
        auth_params[:pw_func] = user.pw_func
        auth_params[:pw_alg] = user.pw_alg
        auth_params[:pw_key_size] = user.pw_key_size
      end

      auth_params
    end

    private

    require 'bcrypt'

    DEFAULT_COST = 11

    def hash_password(password)
      BCrypt::Password.create(password, cost: DEFAULT_COST).to_s
    end

    def test_password(password, hash)
      bcrypt = BCrypt::Password.new(hash)
      password = BCrypt::Engine.hash_secret(password, bcrypt.salt)
      ActiveSupport::SecurityUtils.secure_compare(password, hash)
    end

    def jwt(user)
      JwtHelper.encode(user_uuid: user.uuid, pw_hash: Digest::SHA256.hexdigest(user.encrypted_password))
    end

    def registration_params(params)
      params.permit(:pw_func, :pw_alg, :pw_cost, :pw_key_size, :pw_nonce, :pw_salt, :version)
    end

    def create_session(user, api_version, user_agent)
      if user.supports_jwt?
        return { user: user, token: jwt(user) }
      end

      session = Session.new(user_uuid: user.uuid, api_version: api_version, user_agent: user_agent)

      unless session.save
        return { error: { message: 'Could not create a session.', status: :bad_request } }
      end

      tokens = {
        access_token: {
          value: session.access_token,
          expire_at: session.access_token_expire_at,
        },
        refresh_token: {
          value: session.refresh_token,
          expire_at: session.refresh_token_expire_at,
        },
      }

      { user: user, token: tokens[:access_token][:value], tokens: tokens }
    end
  end
end
