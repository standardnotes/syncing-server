class Session < ApplicationRecord
  belongs_to :user, foreign_key: 'user_uuid'

  validates :user_agent, length: { in: 0..255, allow_nil: true }
  validates :api_version, inclusion: { in: %w(20200115) }

  has_secure_token :access_token
  has_secure_token :refresh_token

  before_create :extend_expiration_dates

  ACCESS_TOKEN_AGE = Rails.application.config.x.session[:access_token_age].seconds
  REFRESH_TOKEN_AGE = Rails.application.config.x.session[:refresh_token_age].seconds

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

  def renew
    return false if refresh_expired?

    regenerate_access_token
    regenerate_refresh_token
    extend_expiration_dates

    save
    true
  end

  def access_expired?
    date_to_milliseconds(access_expiration) < date_to_milliseconds(DateTime.now)
  end

  def refresh_expired?
    date_to_milliseconds(refresh_expiration) < date_to_milliseconds(DateTime.now)
  end

  def device_info
    client = DeviceDetector.new user_agent

    unless client.known?
      return user_agent
    end

    "#{client.name} #{client.full_version} on #{client.os_name} #{client.os_full_version}"
  end

  def as_client_payload
    {
      access_token: access_token,
      refresh_token: refresh_token,
      access_expiration: date_to_milliseconds(access_expiration),
      refresh_expiration: date_to_milliseconds(refresh_expiration),
    }
  end

  private

  def extend_expiration_dates
    self.access_expiration = DateTime.now + ACCESS_TOKEN_AGE
    self.refresh_expiration = DateTime.now + REFRESH_TOKEN_AGE
  end

  def date_to_milliseconds(date)
    date.to_datetime.strftime('%Q').to_i
  end
end
