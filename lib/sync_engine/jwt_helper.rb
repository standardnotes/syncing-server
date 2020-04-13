module SyncEngine
  module JwtHelper
    require 'jwt'

    def self.secret_key_base
      Rails.application.secrets.secret_key_base
    end

    def self.encode(payload)
      JWT.encode(payload, secret_key_base, 'HS256')
    end

    def self.decode(token)
      decoded_token = JWT.decode(token, secret_key_base, true, algorithm: 'HS256')[0]
      HashWithIndifferentAccess.new(decoded_token)
    rescue StandardError => e
      nil
    end
  end
end
