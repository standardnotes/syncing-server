class Api::ItemsController < Api::ApiController
  def sync
    options = {
      sync_token: params[:sync_token],
      cursor_token: params[:cursor_token],
      limit: params[:limit],
      content_type: params[:content_type],
    }

    results = sync_manager.sync(params[:items], options, request)

    begin
      post_to_realtime_extensions(params.to_unsafe_hash[:items])

      # if saved_items contains daily backup extension, trigger that extension so that it executes
      # (allows immediate sync on setup to ensure proper installation)
      backup_extensions = results[:saved_items].select { |item| item.daily_backup_extension? && !item.deleted }
      unless backup_extensions.empty?
        backup_extensions.each(&:perform_associated_job)
      end
    rescue
    end

    if params[:compute_integrity]
      results[:integrity_hash] = current_user.compute_data_signature
    end

    render json: results
  end

  def post_to_realtime_extensions(items)
    if !items || items.empty?
      return
    end

    extensions = current_user.items.where(content_type: 'SF|Extension', deleted: false)
    extensions.each do |ext|
      content = ext.decoded_content
      next unless content
      frequency = content['frequency']
      if frequency == 'realtime'
        post_to_extension(content['url'], items, ext, frequency)
      end
    end
  end

  def post_to_extension(url, items, ext, frequency)
    return unless url && !url.empty?

    ExtensionJob.perform_later(
      current_user.uuid,
      url,
      ext.uuid,
      items.map { |i| i[:uuid] },
      frequency == 'realtime'
    )
  end

  # Writes all user data to backup extension.
  # This is called when a new extension is registered.
  def backup
    ext = current_user.items.find(params[:uuid])
    content = ext.decoded_content
    if content && content['subtype'].nil?
      items = current_user.items.to_a
      if items && !items.empty?
        post_to_extension(content['url'], items, ext, content['frequency'])
      end
    end
  end

  ## Rest API

  def create
    item = current_user.items.new(params[:item].permit(*permitted_params))
    item.save
    render json: { item: item }
  end

  def destroy
    ids = params[:uuids] || [params[:uuid]]
    sync_manager.destroy_items(ids)
    render json: {}, status: :no_content
  end

  private

  def permitted_params
    [:content_type, :content, :auth_hash, :enc_item_key, :items_key_id, :duplicate_of]
  end

  def sync_manager
    version = params[:api]

    # If no version is present, this implies an older client version.
    # In this case, the oldest API version should be used.
    unless version
      return SyncEngine::V20161215::SyncManager.new(current_user)
    end

    # All other clients should specify a valid API version.
    case version
    when '20200115'
      SyncEngine::V20200115::SyncManager.new(current_user)
    when '20190520'
      SyncEngine::V20190520::SyncManager.new(current_user)
    else
      raise InvalidApiVersion
    end
  end
end
