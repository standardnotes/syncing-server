module SyncEngine
  module V20161215
    class UserManager < SyncEngine::AbstractUserManager
      require 'bcrypt'

      def success_auth_response(user, _params)
        token = JwtHelper.encode(
          user_uuid: user.uuid,
          pw_hash: Digest::SHA256.hexdigest(user.encrypted_password)
        )
        return { user: user, token: token }
      end

      DEFAULT_COST = 11
      def hash_password(password)
        BCrypt::Password.create(password, cost: DEFAULT_COST).to_s
      end

      def test_password(password, hash)
        bcrypt = BCrypt::Password.new(hash)
        password = BCrypt::Engine.hash_secret(password, bcrypt.salt)
        ActiveSupport::SecurityUtils.secure_compare(password, hash)
      end
    end
  end
end
