class Item < ApplicationRecord
  belongs_to :user, foreign_key: 'user_uuid', optional: true
  has_many :item_revisions, foreign_key: 'item_uuid'
  has_many :revisions, -> { order 'revisions.created_at DESC' }, through: :item_revisions

  after_save :persist_revision

  MAX_REVISIONS_PER_DAY = 8
  MIN_REVISIONS_PER_DAY = 4

  def serializable_hash(options = {})
    allowed_options = [
      'uuid',
      'items_key_id',
      'enc_item_key',
      'content',
      'content_type',
      'auth_hash',
      'deleted',
      'created_at',
      'updated_at',
    ]

    super(options.merge(only: allowed_options))
  end

  def decoded_content
    if content.nil?
      return nil
    end

    begin
      string = content[3..content.length]
      decoded = Base64.decode64(string)

      JSON.parse(decoded)
    rescue
      nil
    end
  end

  def mark_as_deleted
    self.deleted = true
    self.content = nil if has_attribute?(:content)
    self.enc_item_key = nil if has_attribute?(:enc_item_key)
    self.auth_hash = nil if has_attribute?(:auth_hash)
    save
  end

  def daily_backup_extension?
    return false if content_type != 'SF|Extension'

    content = decoded_content
    content && content['frequency'] == 'daily'
  end

  def perform_associated_job
    content = decoded_content
    return unless content

    if content['subtype'] == 'backup.email_archive'
      # email job
      ArchiveMailer.data_backup(user_uuid).deliver_later
    elsif content['frequency'] == 'daily'
      # backup job
      return unless content['url']
      ExtensionJob.perform_later(url: content['url'], user_id: user_uuid, extension_id: uuid)
    end
  end

  def get_revision_history(days)
    revisions = []
    days.times do |days_from_today|
      allowed_revisions_count = [days - days_from_today + MIN_REVISIONS_PER_DAY, MAX_REVISIONS_PER_DAY].min
      revisions += get_revisions_for_a_day(days_from_today, allowed_revisions_count)
    end
    revisions
  end

  private

  def get_revisions_for_a_day(days_from_today, allowed_revisions_count)
    date = Time.now.utc.to_date - days_from_today
    revisions_from_date = revisions.where(created_at: date.midnight..date.end_of_day)

    if revisions_from_date.length <= allowed_revisions_count
      return revisions
    end

    limit_revisions(revisions_from_date, allowed_revisions_count)
  end

  def limit_revisions(revisions, allowed_revisions_count)
    keep_every_nth = (revisions.length.to_f / allowed_revisions_count).ceil
    keep = [revisions.length - 1]

    (0..revisions.length - keep_every_nth).step(keep_every_nth) do |n|
      keep.push(revisions[n])
    end

    keep
  end

  def persist_revision
    revision = Revision.new
    revision.content = content
    revision.content_type = content_type
    revision.user_uuid = user_uuid
    revision.enc_item_key = enc_item_key
    revision.auth_hash = auth_hash
    revision.save

    item_revision = ItemRevision.new
    item_revision.item_uuid = uuid
    item_revision.revision_uuid = revision.uuid
    item_revision.save
  end
end
