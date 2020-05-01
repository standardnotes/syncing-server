class Session < ApplicationRecord
  validates :user_agent, length: { in: 0..255, allow_nil: true }
  validates :api_version, inclusion: { in: %w(20200115) }

  has_secure_token :access_token
  has_secure_token :refresh_token

  before_create :set_expire_at

  def serializable_hash(options = {})
    allowed_options = [
      'uuid',
      'api_version',
      'created_at',
      'updated_at',
    ]

    allowed_methods = [
      'device_info',
    ]

    super(options.merge(only: allowed_options, methods: allowed_methods))
  end

  def access_token_expire_at
    (expire_at - refresh_token_expiration_time + access_token_expiration_time).to_i
  end

  def refresh_token_expire_at
    expire_at.to_i
  end

  def regenerate_tokens
    return false if self.expired?

    regenerate_access_token
    regenerate_refresh_token
    set_expire_at

    return true
  end

  def expired?
    refresh_token_expire_at < DateTime.now.to_i
  end

  def device_info
    client = DeviceDetector.new user_agent

    unless client.known?
      return user_agent
    end

    "#{client.name} #{client.full_version} on #{client.os_name} #{client.os_full_version}"
  end

  private

  def config
    Rails.application.config.x.session
  end

  def refresh_token_expiration_time
    config[:refresh_token_expiration_time].seconds
  end

  def access_token_expiration_time
    config[:access_token_expiration_time].seconds
  end

  def set_expire_at
    self.expire_at = DateTime.now + refresh_token_expiration_time
  end
end
