module SyncEngine
  class AbstractSyncManager
    attr_writer :sync_fields

    def initialize(user)
      @user = user
      raise 'User must be set' unless @user
    end

    def sync_fields
      @sync_fields || [:content, :enc_item_key, :content_type, :auth_hash, :deleted, :created_at]
    end

    def destroy_items(uuids)
      items = @user.items.where(uuid: uuids)
      items.destroy_all
    end

    private

    def sync_token_from_datetime(datetime)
      version = 2
      Base64.encode64("#{version}:" + datetime.to_f.to_s)
    end

    def datetime_from_sync_token(sync_token)
      decoded = Base64.decode64(sync_token)
      parts = decoded.rpartition(':')
      timestamp_string = parts.last
      version = parts.first
      if version == '1'
        date = DateTime.strptime(timestamp_string, '%s')
      elsif version == '2'
        date = Time.at(timestamp_string.to_f).to_datetime.utc
      end

      date
    end

    def item_params
      params.permit(*permitted_params)
    end

    def permitted_params
      sync_fields
    end
  end
end
