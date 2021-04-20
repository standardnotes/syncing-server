module SyncEngine
  module V20200115
    class SyncManager < SyncEngine::V20190520::SyncManager
      def sync(item_hashes, options, request)
        in_sync_token = options[:sync_token]
        in_cursor_token = options[:cursor_token]
        limit = options[:limit].to_i
        # Optional, only return items of these type if present
        content_type = options[:content_type]

        retrieved_items, cursor_token = _sync_get(in_sync_token, in_cursor_token, limit, content_type).to_a
        last_updated = DateTime.now
        saved_items, conflicts = _sync_save(item_hashes, request, retrieved_items)

        if in_sync_token.nil?
          # If it's the first sync request, front-load all exisitng items keys
          # so that the client can decrypt incoming items without having to wait
          @user.items_keys.each do |items_key|
            retrieved_items.unshift(items_key) unless retrieved_items.include?(items_key)
          end
        end

        unless saved_items.empty?
          last_updated = saved_items.sort_by(&:updated_at).last.updated_at
        end

        # add 1 microsecond to avoid returning same object in subsequent sync
        last_updated = (last_updated.to_time + 1 / 100000.0).to_datetime.utc
        sync_token = sync_token_from_datetime(last_updated)

        {
          retrieved_items: retrieved_items,
          saved_items: saved_items,
          conflicts: conflicts,
          sync_token: sync_token,
          cursor_token: cursor_token,
        }
      end
    end
  end
end
