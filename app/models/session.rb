class Session < ApplicationRecord
  belongs_to :user, foreign_key: 'user_uuid'

  validates :user_agent, length: { in: 0..255, allow_nil: true }
  validates :api_version, inclusion: { in: %w(20200115) }

  before_create do
    set_expiration_dates
  end

  SESSION_TOKEN_VERSION = 1

  ACCESS_TOKEN_AGE = Rails.application.config.x.session[:access_token_age].seconds
  REFRESH_TOKEN_AGE = Rails.application.config.x.session[:refresh_token_age].seconds

  def self.hash_string(string)
    Digest::SHA256.hexdigest(string)
  end

  def create_tokens
    access_token = SecureRandom.urlsafe_base64
    refresh_token = SecureRandom.urlsafe_base64
    self.hashed_access_token = Session.hash_string(access_token)
    self.hashed_refresh_token = Session.hash_string(refresh_token)
    return access_token, refresh_token
  end

  def self.from_token(request_token)
    _version, session_id, access_token = Session.deconstruct_token(request_token)

    Rails.logger.debug "Retrieving session #{session_id} from token"

    ephemeral_session = get_ephemeral_session(session_id)

    unless ephemeral_session.nil?
      Rails.logger.debug "Retrieved an ephemeral session from cache: #{ephemeral_session}"

      session = Session.from_ephemeral_session(ephemeral_session)
    end

    session = Session.find_by_uuid(session_id) if session.nil?

    if session && !access_token.nil?
      return session if ActiveSupport::SecurityUtils.secure_compare(
        session.hashed_access_token,
        Session.hash_string(access_token)
      )
    end
  end

  def self.from_ephemeral_session(ephemeral_session)
    parsed_ephemeral_session = JSON.parse(ephemeral_session)

    Session.new(
      uuid: parsed_ephemeral_session['uuid'],
      user_uuid: parsed_ephemeral_session['userUuid'],
      api_version: parsed_ephemeral_session['apiVersion'],
      user_agent: parsed_ephemeral_session['userAgent'],
      hashed_access_token: parsed_ephemeral_session['hashedAccessToken'],
      hashed_refresh_token: parsed_ephemeral_session['hashedRefreshToken'],
      access_expiration: Date.parse(parsed_ephemeral_session['accessExpiration']),
      refresh_expiration: Date.parse(parsed_ephemeral_session['refreshExpiration']),
      created_at: Date.parse(parsed_ephemeral_session['createdAt']),
      updated_at: Date.parse(parsed_ephemeral_session['updatedAt'])
    )
  end

  def self.get_ephemeral_session(session_id)
    unless ENV['REDIS_URL'].present?
      Rails.logger.warn 'Skipped search for ephemeral session. Redis not connected.'

      return
    end

    keys = Redis.current.scan_each(match: "session:#{session_id}:*").to_a.uniq

    if keys.length.positive?
      Redis.current.get(keys.first)
    end
  end

  def valid_refresh_token?(request_token)
    _version, _session_id, refresh_token = Session.deconstruct_token(request_token)
    !refresh_token.nil? && ActiveSupport::SecurityUtils.secure_compare(
      Session.hash_string(refresh_token),
      hashed_refresh_token
    )
  end

  def self.construct_token(uuid, token)
    "#{SESSION_TOKEN_VERSION}:#{uuid}:#{token}"
  end

  def self.deconstruct_token(token)
    token.split(':')
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
    return nil, nil if refresh_expired?

    access_token, refresh_token = create_tokens
    set_expiration_dates

    save
    return access_token, refresh_token
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

  def as_client_payload(access_token, refresh_token)
    if access_token.nil? || refresh_token.nil?
      raise 'access_token and refresh_token parameters required.'
    end
    {
      access_token: Session.construct_token(uuid, access_token),
      refresh_token: Session.construct_token(uuid, refresh_token),
      access_expiration: date_to_milliseconds(access_expiration),
      refresh_expiration: date_to_milliseconds(refresh_expiration),
    }
  end

  private

  def set_expiration_dates
    self.access_expiration = DateTime.now + ACCESS_TOKEN_AGE
    self.refresh_expiration = DateTime.now + REFRESH_TOKEN_AGE
  end

  def date_to_milliseconds(date)
    date.to_datetime.strftime('%Q').to_i
  end
end
