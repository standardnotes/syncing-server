class Item < ApplicationRecord
  belongs_to :user, foreign_key: 'user_uuid', optional: true
  has_many :item_revisions, foreign_key: 'item_uuid', dependent: :destroy
  has_many :revisions, through: :item_revisions, dependent: :destroy

  after_commit :save_revision
  after_create :duplicate_revisions

  def serializable_hash(options = {})
    allowed_options = [
      'uuid',
      'items_key_id',
      'duplicate_of',
      'enc_item_key',
      'content',
      'content_type',
      'auth_hash',
      'deleted',
      'created_at',
      'updated_at',
    ]

    super(options.merge(only: allowed_options)).merge({
      "created_at" => created_at&.iso8601(6),
      "updated_at" => updated_at&.iso8601(6),
    })
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
      ArchiveMailer.data_backup(user_uuid, uuid).deliver_later
    elsif content['frequency'] == 'daily'
      # backup job
      return unless content['url']

      ExtensionJob.perform_later(user_uuid, content['url'], uuid)
    end
  end

  def can_save_revision?
    return true unless updated_at_before_last_save

    seconds_from_last_revision = ((Time.now - updated_at_before_last_save) / 1.second).round
    revisions_frequency = ENV['REVISIONS_FREQUENCY'] ? ENV['REVISIONS_FREQUENCY'].to_i : 300

    seconds_from_last_revision >= revisions_frequency
  end

  private

  def duplicate_revisions
    return if content_type != 'Note' || !duplicate_of?

    DuplicateRevisionsJob.perform_later(uuid)
  end

  def save_revision
    return if content_type != 'Note' || !can_save_revision?

    revision = Revision.new
    revision.auth_hash = auth_hash
    revision.content = content
    revision.content_type = content_type
    revision.creation_date = Date.today
    revision.enc_item_key = enc_item_key
    revision.item_uuid = uuid
    revision.items_key_id = items_key_id
    revision.save

    item_revision = ItemRevision.new
    item_revision.item_uuid = uuid
    item_revision.revision_uuid = revision.uuid
    item_revision.save
  end
end
