module SyncEngine
  class AbstractSyncManager

    attr_accessor :sync_fields

    def initialize(user)
      @user = user
      raise "User must be set" unless @user
    end

    def set_sync_fields(val)
      @sync_fields = val
    end

    def sync_fields
      return @sync_fields || [:content, :enc_item_key, :content_type, :auth_hash, :deleted, :created_at]
    end

    def destroy_items(uuids)
      items = @user.items.where(uuid: uuids)
      items.destroy_all
    end

    private

    def sync_token_from_datetime(datetime)
      version = 2
      Base64.encode64("#{version}:" + "#{datetime.to_f}")
    end

    def datetime_from_sync_token(sync_token)
      decoded = Base64.decode64(sync_token)
      parts = decoded.rpartition(":")
      timestamp_string = parts.last
      version = parts.first
      if version == "1"
        date = DateTime.strptime(timestamp_string,'%s')
      elsif version == "2"
        date = Time.at(timestamp_string.to_f).to_datetime.utc
      end

      return date
    end

    def set_deleted(item)
      item.deleted = true
      item.content = nil if item.has_attribute?(:content)
      item.enc_item_key = nil if item.has_attribute?(:enc_item_key)
      item.auth_hash = nil if item.has_attribute?(:auth_hash)
    end

    def item_params
      params.permit(*permitted_params)
    end

    def permitted_params
      sync_fields
    end

  end
end
