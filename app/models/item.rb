class Item < ApplicationRecord
  MAX_REVISIONS_PER_DAY = 30
  MIN_REVISIONS_PER_DAY = 2

  belongs_to :user, foreign_key: 'user_uuid', optional: true
  has_many :item_revisions, foreign_key: 'item_uuid', dependent: :destroy
  has_many :revisions, through: :item_revisions, dependent: :destroy

  after_commit :persist_revision
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
      ArchiveMailer.data_backup(user_uuid, uuid).deliver_later
    elsif content['frequency'] == 'daily'
      # backup job
      return unless content['url']

      ExtensionJob.perform_later(user_uuid, content['url'], uuid)
    end
  end

  def cleanup_revisions(days)
    last_days_of_revisions = revisions
      .select(:creation_date)
      .order(creation_date: :desc)
      .group(:creation_date)
      .take(days)

    days_to_process = []
    last_days_of_revisions.each do |revision|
      days_to_process.push(revision.creation_date)
    end

    days_to_process.each do |day|
      days_from_today = (DateTime.now - day).to_i
      allowed_revisions_count = [[days - days_from_today, MAX_REVISIONS_PER_DAY].min, MIN_REVISIONS_PER_DAY].max
      cleanup_revisions_for_a_day(days_from_today, allowed_revisions_count)
    end
  end

  private

  def duplicate_revisions
    if content_type == 'Note' && duplicate_of?
      DuplicateRevisionsJob.perform_later(uuid)
    end
  end

  def persist_revision
    if content_type == 'Note' && !uuid_before_last_save.nil?
      revision = Revision.new
      revision.auth_hash = auth_hash_before_last_save
      revision.content = content_before_last_save
      revision.content_type = content_type_before_last_save
      revision.creation_date = Date.today
      revision.enc_item_key = enc_item_key_before_last_save
      revision.item_uuid = uuid
      revision.items_key_id = items_key_id_before_last_save
      revision.save

      item_revision = ItemRevision.new
      item_revision.item_uuid = uuid
      item_revision.revision_uuid = revision.uuid
      item_revision.save
    end
  end

  def cleanup_revisions_for_a_day(days_from_today, allowed_revisions_count)
    date = Time.now.utc.to_date - days_from_today
    revisions_from_date_count = revisions.where(creation_date: date).count

    if revisions_from_date_count > allowed_revisions_count
      revisions_from_date = revisions
        .select(:uuid)
        .where(creation_date: date)
        .order(creation_date: :desc)
        .pluck(:uuid)

      revisions_slice_size = (revisions_from_date.length.to_f / allowed_revisions_count).floor
      revisions_divided_into_slices = revisions_from_date.each_slice(revisions_slice_size).to_a
      first_slice = revisions_divided_into_slices.shift
      last_slice = revisions_divided_into_slices.pop

      revisions_to_keep = [
        first_slice.first,
        last_slice.last,
      ]

      beginning_counter = 0
      end_counter = revisions_divided_into_slices.length - 1
      counter = 0
      while revisions_to_keep.length < allowed_revisions_count
        if counter.odd?
          revisions_to_keep.push(
            revisions_divided_into_slices[beginning_counter][
              (revisions_divided_into_slices[beginning_counter].length.to_f / 2).floor
            ]
          )
          beginning_counter += 1
        else
          revisions_to_keep.push(
            revisions_divided_into_slices[end_counter][
              (revisions_divided_into_slices[end_counter].length.to_f / 2).floor
            ]
          )
          end_counter -= 1
        end

        counter += 1
      end

      Revision
        .using(:master)
        .where(item_uuid: uuid)
        .where(creation_date: date)
        .where.not(uuid: revisions_to_keep)
        .delete_all

      ItemRevision
        .using(:master)
        .where(item_uuid: uuid)
        .where(revision_uuid: revisions_from_date.difference(revisions_to_keep))
        .delete_all
    end
  end
end
