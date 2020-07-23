class Item < ApplicationRecord
  belongs_to :user, foreign_key: 'user_uuid', optional: true
  has_many :item_revisions, foreign_key: 'item_uuid', dependent: :destroy
  has_many :revisions, -> { order 'revisions.created_at DESC' }, through: :item_revisions, dependent: :destroy

  after_commit :persist_revision, :cleanup_excessive_revisions
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
      ExtensionJob.perform_later(url: content['url'], user_id: user_uuid, extension_id: uuid, silent: false)
    end
  end

  private

  def cleanup_excessive_revisions(days = User::REVISIONS_RETENTION_DAYS)
    if content_type == 'Note'
      CleanupRevisionsJob.perform_later(uuid, days)
    end
  end

  def duplicate_revisions
    if content_type == 'Note' && duplicate_of?
      DuplicateRevisionsJob.perform_later(uuid)
    end
  end

  def persist_revision
    if content_type == 'Note' && !uuid_before_last_save.nil?
      revision = Revision.new
      revision.content = content_before_last_save
      revision.content_type = content_type_before_last_save
      revision.enc_item_key = enc_item_key_before_last_save
      revision.items_key_id = items_key_id_before_last_save
      revision.auth_hash = auth_hash_before_last_save
      revision.save

      item_revision = ItemRevision.new
      item_revision.item_uuid = uuid
      item_revision.revision_uuid = revision.uuid
      item_revision.save
    end
  end
end
