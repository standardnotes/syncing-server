class Session < ApplicationRecord
  belongs_to :user, foreign_key: 'user_uuid'

  validates :user_agent, length: { in: 0..255, allow_nil: true }
  validates :api_version, inclusion: { in: %w(20200115) }

  before_create do
    extend_expiration_dates
  end

  ACCESS_TOKEN_AGE = Rails.application.config.x.session[:access_token_age].seconds
  REFRESH_TOKEN_AGE = Rails.application.config.x.session[:refresh_token_age].seconds
  SESSION_TOKEN_VERSION = 1

  def self.create_hash_from_value(value)
    Digest::SHA256.hexdigest(value)
  end

  def self.generate_tokens
    access_token = SecureRandom.urlsafe_base64
    refresh_token = SecureRandom.urlsafe_base64
    {
      access_token: access_token,
      refresh_token: refresh_token,
    }
  end

  def self.authenticate(request_token)
    _version, session_id, access_token = request_token.split(':')
    session = Session.find_by_uuid(session_id)
    if session && !access_token.nil?
      hashed_access_token = Session.create_hash_from_value(access_token)
      if ActiveSupport::SecurityUtils.secure_compare(session.hashed_access_token, hashed_access_token)
        session
      end
    end
  end

  def valid_refresh_token?(request_token)
    _version, _session_id, refresh_token = request_token.split(':')
    hashed_token = Session.create_hash_from_value(refresh_token)
    !refresh_token.nil? && ActiveSupport::SecurityUtils
      .secure_compare(hashed_token, hashed_refresh_token)
  end

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

  def renew(access_token:, refresh_token:)
    return false if refresh_expired?
    return false if access_token.nil? || refresh_token.nil?

    set_hashed_tokens({ access_token: access_token, refresh_token: refresh_token, })
    extend_expiration_dates

    save
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

  def set_hashed_tokens(access_token:, refresh_token:)
    self.hashed_access_token = Session.create_hash_from_value(access_token)
    self.hashed_refresh_token = Session.create_hash_from_value(refresh_token)
    save
  end

  def as_client_payload(access_token:, refresh_token:)
    if access_token.nil? || refresh_token.nil?
      throw 'access_token and refresh_token parameters required.'
    end
    {
      access_token: "#{SESSION_TOKEN_VERSION}:#{uuid}:#{access_token}",
      refresh_token: "#{SESSION_TOKEN_VERSION}:#{uuid}:#{refresh_token}",
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
