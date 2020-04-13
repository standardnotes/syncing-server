class User < ApplicationRecord
  validates :email, presence: true, uniqueness: true
  validates :encrypted_password, presence: true

  has_many :items, -> { order 'created_at desc' }, foreign_key: 'user_uuid'
  has_many :sessions, -> { order 'created_at desc' }, foreign_key: 'user_uuid'

  def serializable_hash(options = {})
    super(options.merge(only: ['email', 'uuid']))
  end

  def auth_params
    params = { pw_cost: pw_cost, version: version, identifier: email }

    if pw_nonce
      params[:pw_nonce] = pw_nonce
    end

    if pw_salt
      params[:pw_salt] = pw_salt
    end

    if pw_func
      params[:pw_func] = pw_func
      params[:pw_alg] = pw_alg
      params[:pw_key_size] = pw_key_size
    end

    params
  end

  ##
  # Returns the items key associated with this user
  def items_keys
    items.where(content_type: 'SN|ItemsKey')
  end

  def download_backup
    data = {
      items: items.where(deleted: false),
      auth_params: auth_params,
    }
    body = JSON.pretty_generate(data.as_json({}))
    File.open("tmp/#{email}-restore.txt", 'w') { |file| file.write(body) }
  end

  def mfa_item
    items.where(content_type: 'SF|MFA', deleted: false).first
  end

  def disable_mfa(force = false)
    mfa = mfa_item
    if mfa
      email_recovery_enabled = mfa.decoded_content['allowEmailRecovery'] == true
      if email_recovery_enabled || force
        mfa.mark_as_deleted
        puts 'MFA has been disabled.'
        UserMailer.mfa_disabled(uuid).deliver_later
      else
        puts 'Unable to disable MFA; user has email recovery disabled.'
      end
    end
  end

  def perform_email_backup
    ArchiveMailer.data_backup(uuid).deliver_later
  end

  def disable_email_backups
    extensions = items.where(content_type: 'SF|Extension', deleted: false)
    extensions.each do |ext|
      content = ext.decoded_content
      if content && content['subtype'] == 'backup.email_archive'
        ext.mark_as_deleted
        puts 'Successfully disabled email backups.'
      end
    end
  end

  def compute_data_signature
    # in my testing, .select performs better than .pluck
    dates = items.where(deleted: false).where.not(content_type: nil)
      .select(:updated_at).map { |item| item.updated_at.to_datetime.strftime('%Q') }

    dates = dates.sort.reverse
    string = dates.join(',')
    hash = Digest::SHA256.hexdigest(string)
    hash
  rescue
    nil
  end

  def bytes_to_megabytes(bytes)
    mb = bytes / (1024.0 * 1024.0)
    string = format('%.2f', mb)
    "#{string}MB"
  end

  def total_data_size
    items = self.items.where(deleted: false)
    total_bytes = 0
    items.each do |item|
      total_bytes += item.content.bytesize
    end

    bytes_to_megabytes(total_bytes)
  end

  def items_by_size
    sorted = items.where(deleted: false).sort_by do |item|
      item.content.bytesize
    end
    sorted.reverse.map { |item| { uuid: item.uuid, size: bytes_to_megabytes(item.content.bytesize) } }
  end

  def active_sessions
    sessions.where('expire_at > ?', DateTime.now).to_a.map(&:serializable_hash)
  end

  def supports_jwt?
    version.to_i < 4
  end

  def supports_sessions?
    version.to_i >= 4
  end
end
