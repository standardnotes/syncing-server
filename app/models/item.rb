class Item < ApplicationRecord

  belongs_to :user, :foreign_key => "user_uuid", optional: true

  def serializable_hash(options = {})
    result = super(options.merge({only: ["uuid", "enc_item_key", "content", "content_type", "auth_hash", "deleted", "created_at", "updated_at"]}))
    result
  end

  def decoded_content
    if self.content == nil
      return nil
    end

    begin
      string = self.content[3..self.content.length]
      decoded = Base64.decode64(string)
      obj = JSON.parse(decoded)
      return obj
    rescue
      return nil
    end
  end

  def mark_as_deleted
    self.deleted = true
    self.content = nil if self.has_attribute?(:content)
    self.enc_item_key = nil if self.has_attribute?(:enc_item_key)
    self.auth_hash = nil if self.has_attribute?(:auth_hash)
    self.save
  end

  def is_daily_backup_extension
    return false if self.content_type != "SF|Extension"

    content = self.decoded_content
    return content && content["frequency"] == "daily"
  end

  def perform_associated_job
    content = self.decoded_content
    return if !content

    if content["subtype"] == "backup.email_archive"
      # email job
      ArchiveMailer.data_backup(self.user_uuid).deliver_later
    elsif content["frequency"] == "daily"
      # backup job
      return if !content["url"]
      ExtensionJob.perform_later({url: content["url"], user_id: self.user_uuid, extension_id: self.uuid})
    end

  end

end
