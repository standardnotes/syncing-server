class Session < ApplicationRecord
  belongs_to :user, foreign_key: 'user_uuid'

  validates :user_agent, length: { in: 0..255, allow_nil: true }
  validates :api_version, inclusion: { in: %w(20200115) }

  attr_accessor :access_token
  attr_accessor :refresh_token

  before_create do
    generate_tokens
    extend_expiration_dates
  end

  ACCESS_TOKEN_AGE = Rails.application.config.x.session[:access_token_age].seconds
  REFRESH_TOKEN_AGE = Rails.application.config.x.session[:refresh_token_age].seconds

  def self.authenticate(request_token)
    _version, session_id, access_token = request_token.split(':')
    session = Session.find_by_uuid(session_id)
    if session && !access_token.nil?
      hashed_access_token = Digest::SHA256.hexdigest(access_token)
      session.hashed_access_token == hashed_access_token ? session : nil
    end
  end

  def valid_refresh_token?(request_token)
    _version, _session_id, refresh_token = request_token.split(':')
    !refresh_token.nil? && hashed_refresh_token == create_hash_from_value(refresh_token)
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

  def renew
    return false if refresh_expired?

    generate_tokens
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

  def as_client_payload
    # TODO: this method should only be called on a newly created instance or after
    # calling renew method. The reason is that access_token and refresh_token are 
    # just class attributes and are not really persisted to database.
    {
      access_token: "1:#{uuid}:#{access_token}",
      refresh_token: "1:#{uuid}:#{refresh_token}",
      access_expiration: date_to_milliseconds(access_expiration),
      refresh_expiration: date_to_milliseconds(refresh_expiration),
    }
  end

  private

  def generate_tokens
    self.access_token = SecureRandom.urlsafe_base64
    self.refresh_token = SecureRandom.urlsafe_base64
    self.hashed_access_token = create_hash_from_value(access_token)
    self.hashed_refresh_token = create_hash_from_value(refresh_token)
  end

  def extend_expiration_dates
    self.access_expiration = DateTime.now + ACCESS_TOKEN_AGE
    self.refresh_expiration = DateTime.now + REFRESH_TOKEN_AGE
  end

  def date_to_milliseconds(date)
    date.to_datetime.strftime('%Q').to_i
  end

  def create_hash_from_value(value)
    Digest::SHA256.hexdigest(value)
  end
end
