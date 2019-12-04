class User < ApplicationRecord

  has_many :items, -> { order 'created_at desc' }, :foreign_key => "user_uuid"

  def serializable_hash(options = {})
    result = super(options.merge({only: ["email", "uuid"]}))
    result
  end

  def auth_params
    params = {:pw_cost => self.pw_cost, :version => self.version, :identifier => self.email}

    if self.pw_nonce
      params[:pw_nonce] = self.pw_nonce
    end

    if self.pw_salt
      params[:pw_salt] = self.pw_salt
    end

    if self.pw_func
      params[:pw_func] = self.pw_func
      params[:pw_alg] = self.pw_alg
      params[:pw_key_size] = self.pw_key_size
    end

    return params
  end

  def export_archive
    data = {:items => self.items.where(:deleted => false), :auth_params => self.auth_params}
    # This will write restore.txt in your application's root directory.
    File.open("tmp/#{self.email}-restore.txt", 'w') { |file| file.write(JSON.pretty_generate(data.as_json({}))) }
  end

  def mfa_item
    self.items.where("content_type" => "SF|MFA", "deleted" => false).first
  end

  def disable_mfa(force = false)
    mfa = self.mfa_item
    if mfa
      email_recovery_enabled = mfa.decoded_content["allowEmailRecovery"] == true
      if email_recovery_enabled || force
        mfa.mark_as_deleted
      else
        puts "User has email recovery disabled."
      end
    end
  end

  def perform_email_backup
    ArchiveMailer.data_backup(self.uuid).deliver_later
  end

  def disable_email_backups
    extensions = self.items.where(:content_type => "SF|Extension", :deleted => false)
    extensions.each do |ext|
      content = ext.decoded_content
      if content && content["subtype"] == "backup.email_archive"
        ext.mark_as_deleted
      end
    end
  end

  def compute_data_signature
    begin
      # in my testing, .select performs better than .pluck
      dates = self.items.where(:deleted => false).where.not(:content_type => nil).select(:updated_at).map { |item| item.updated_at.to_datetime.strftime('%Q')  }
      dates = dates.sort().reverse
      string = dates.join(",")
      hash = Digest::SHA256.hexdigest(string)
      return hash
    rescue
      return nil
    end
  end

  def bytes_to_megabytes(bytes)
    mb = bytes / (1024.0 * 1024.0)
    string = "%.2f" % mb
    "#{string}MB"
  end

  def total_data_size
    items = self.items.where(:deleted => false)
    total_bytes = 0
    items.each do |item|
      total_bytes += item.content.bytesize
    end

    bytes_to_megabytes(total_bytes)
  end

  def items_by_size
    sorted = self.items.where(:deleted => false).sort_by { |item|
      item.content.bytesize
    }
    return sorted.reverse.map { |item| {uuid: item.uuid, size: bytes_to_megabytes(item.content.bytesize)}  }
  end

end
