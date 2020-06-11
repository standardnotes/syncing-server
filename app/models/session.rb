class Session < ApplicationRecord
  belongs_to :user, foreign_key: 'user_uuid'

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
    expire_date = (expire_at - refresh_token_expiration_time + access_token_expiration_time)
    timestamp_ms(expire_date)
  end

  def refresh_token_expire_at
    timestamp_ms(expire_at)
  end

  def regenerate_tokens
    return false if expired?

    regenerate_access_token
    regenerate_refresh_token
    set_expire_at

    save
    true
  end

  def expired_access_token?
    access_token_expire_at < timestamp_ms
  end

  def expired?
    refresh_token_expire_at < timestamp_ms
  end

  def device_info
    client = DeviceDetector.new user_agent

    unless client.known?
      return user_agent
    end

    "#{client.name} #{client.full_version} on #{client.os_name} #{client.os_full_version}"
  end

  def response_hash
    {
      session: {
        expire_at: access_token_expire_at,
        refresh_token: refresh_token,
        valid_until: refresh_token_expire_at,
      },
      token: access_token,
      user: user,
    }
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

  def timestamp_ms(date = nil)
    date = DateTime.now if date.nil?
    date.to_datetime.strftime('%Q').to_i
  end
end
