module SyncEngine
  module JwtHelper
    require 'jwt'

    def self.secret_key_base
      Rails.application.secrets.secret_key_base
    end

    def self.legacy_secret_key_base
      ENV['LEGACY_SECRET_KEY_BASE']
    end

    def self.encode(payload)
      JWT.encode(payload, secret_key_base, 'HS256')
    end

    def self.decode(token)
      Rails.logger.debug "Decoding JWT token #{token} with secret key base"

      decoded_token = JWT.decode(token, secret_key_base, true, algorithm: 'HS256')[0]
      HashWithIndifferentAccess.new(decoded_token)
    rescue StandardError => e
      Rails.logger.debug "Could not decode JWT token with secret key base: #{e.message}"

      begin
        Rails.logger.debug "Decoding JWT token #{token} with legacy secret key base"

        decoded_token = JWT.decode(token, legacy_secret_key_base, true, algorithm: 'HS256')[0]
        HashWithIndifferentAccess.new(decoded_token)
      rescue StandardError => legacy_e
        Rails.logger.debug "Could not decode JWT token with legacy secret key base: #{legacy_e.message}"

        nil
      end
    end
  end
end
