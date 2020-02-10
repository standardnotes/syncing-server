class Api::ItemsController < Api::ApiController

  def sync_manager
    if !@sync_manager
      version = params[:api]
      if version == "20190520"
        @sync_manager = SyncEngine::V20190520::SyncManager.new(current_user)
      else
        @sync_manager = SyncEngine::V20161215::SyncManager.new(current_user)
      end
    end
    @sync_manager
  end

  def sync
    options = {
      :sync_token => params[:sync_token],
      :cursor_token => params[:cursor_token],
      :limit => params[:limit],
      :content_type => params[:content_type]
    }

    if params[:event]
      Raven.capture_message(params[:event])
    end

    results = sync_manager.sync(params[:items], options, request)

    begin
      post_to_realtime_extensions(params.to_unsafe_hash[:items])

      # if saved_items contains daily backup extension, trigger that extension so that it executes
      # (allows immediate sync on setup to ensure proper installation)
      backup_extensions = results[:saved_items].select{|item| item.is_daily_backup_extension && !item.deleted}
      if backup_extensions.length > 0
        backup_extensions.each do |ext|
          ext.perform_associated_job
        end
      end
    rescue
    end

    if params[:compute_integrity]
      results[:integrity_hash] = current_user.compute_data_signature
    end

    render :json => results
  end

  def post_to_realtime_extensions(items)
    if !items || items.length == 0
      return
    end

    extensions = current_user.items.where(:content_type => "SF|Extension", :deleted => false)
    extensions.each do |ext|
      content = ext.decoded_content
      if content
        frequency = content["frequency"]
        if frequency == "realtime"
          post_to_extension(content["url"], items, ext)
        end
      end
    end
  end

  def post_to_extension(url, items, ext)
    if url && url.length > 0
      params = {
        url: url,
        item_ids: items.map { |i| i[:uuid] },
        user_id: current_user.uuid,
        extension_id: ext.uuid
      }
      ExtensionJob.perform_later(params)
    end
  end

  # Writes all user data to backup extension.
  # This is called when a new extension is registered.
  def backup
    ext = current_user.items.find(params[:uuid])
    content = ext.decoded_content
    if content && content["subtype"].nil?
      items = current_user.items.to_a
      if items && items.length > 0
        post_to_extension(content["url"], items, ext)
      end
    end
  end

  ## Rest API

  def create
    item = current_user.items.new(params[:item].permit(*permitted_params))
    item.save
    render :json => {:item => item}
  end

  def destroy
    ids = params[:uuids] || [params[:uuid]]
    sync_manager.destroy_items(ids)
    render :json => {}, :status => 204
  end

  private

  def permitted_params
    [:content_type, :content, :auth_hash, :enc_item_key]
  end

end
