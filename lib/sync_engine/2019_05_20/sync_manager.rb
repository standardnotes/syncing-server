module SyncEngine
  module V20190520
    class SyncManager < SyncEngine::AbstractSyncManager
      def sync(item_hashes, options, request)
        in_sync_token = options[:sync_token]
        in_cursor_token = options[:cursor_token]
        limit = options[:limit].to_i
        content_type = options[:content_type] # optional, only return items of these type if present

        retrieved_items, cursor_token = _sync_get(in_sync_token, in_cursor_token, limit, content_type).to_a
        last_updated = DateTime.now
        saved_items, conflicts = _sync_save(item_hashes, request, retrieved_items)

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

      # Ignore differences that are at most this many seconds apart
      # Anything over this threshold will be conflicted.
      MIN_CONFLICT_INTERVAL = 1.0

      def _sync_save(item_hashes, request, retrieved_items)
        unless item_hashes
          return [], []
        end

        saved_items = []
        conflicts = []

        item_hashes.each do |item_hash|
          is_new_record = false
          begin
            item = @user.items.find_or_create_by(uuid: item_hash[:uuid]) do |_created_item|
              # this block is executed if this is a new record.
              is_new_record = true
            end
          rescue
            conflicts.push(
              unsaved_item: item_hash,
              type: 'uuid_conflict',
            )
            next
          end

          # SFJS did not send updated_at prior to 0.3.59.
          # updated_at value from client will not be saved, as it is not a permitted_param.
          incoming_updated_at = if item_hash['updated_at']
            DateTime.parse(item_hash['updated_at'])
          else
            # Default to epoch
            Time.at(0).to_datetime
          end

          unless is_new_record
            # We want to check if this updated_at value is equal to the item's current updated_at value.
            # If they differ, it means the client is attempting to save an item which hasn't been updated.
            # In this case, if the incoming_item.updated_at < server_item.updated_at, always conflict.
            # We don't want old items overriding newer ones.
            # incoming_item.updated_at > server_item.updated_at would seem to be impossible,
            # as only servers are responsible for setting updated_at.
            # But assuming a rogue client has gotten away with it,
            # we should also conflict in this case if the difference between the dates is greater
            # than MIN_CONFLICT_INTERVAL seconds.

            our_updated_at = item.updated_at
            difference = incoming_updated_at.to_f - our_updated_at.to_f

            save_incoming = if difference < 0
              # incoming is less than ours. This implies stale data. Don't save if greater than interval
              difference.abs < MIN_CONFLICT_INTERVAL
            elsif difference > 0
              # incoming is greater than ours. Should never be the case. If so though, don't save.
              difference.abs < MIN_CONFLICT_INTERVAL
            else
              # incoming is equal to ours (which is desired, healthy behavior), continue with saving.
              true
            end

            unless save_incoming
              # Dont save incoming and send it back. At this point the server item is likely to be included
              # in retrieved_items in a subsequent sync, so when that value comes into the client,
              server_value = item.as_json({})
              conflicts.push(
                server_item: server_value, # as_json to get values as-is, befor modifying below,
                type: 'sync_conflict',
              )

              retrieved_items.delete(item)
              next
            end
          end

          item.last_user_agent = request.user_agent
          item.update(item_hash.permit(*permitted_params))

          if item.deleted == true
            item.mark_as_deleted
          end

          saved_items.push(item)
        end

        [saved_items, conflicts]
      end

      def _sync_get(sync_token, input_cursor_token, limit, content_type)
        cursor_token = nil
        if limit.nil? || limit < 1
          limit = 100000
        end

        # if both are present, cursor_token takes precendence as that would eventually return all results
        # the distinction between getting results for a cursor and a sync token is that cursor results use a
        # >= comparison, while a sync token uses a > comparison. The reason for this is that cursor tokens are
        # typically used for initial syncs or imports, where a bunch of notes could have the exact same updated_at
        # by using >=, we don't miss those results on a subsequent call with a cursor token
        if input_cursor_token
          date = datetime_from_sync_token(input_cursor_token)
          items = @user.items.order(:updated_at).where('updated_at >= ?', date)
        elsif sync_token
          date = datetime_from_sync_token(sync_token)
          items = @user.items.order(:updated_at).where('updated_at > ?', date)
        else
          # if no cursor token and no sync token, this is an initial sync. No need to return deleted items.
          items = @user.items.order(:updated_at).where(deleted: false)
        end

        if content_type
          items = items.where(content_type: content_type)
        end

        items = items.sort_by(&:updated_at)

        if !items.empty? && items.count > limit
          items = items.slice(0, limit)
          date = items.last.updated_at
          cursor_token = sync_token_from_datetime(date)
        end

        [items, cursor_token]
      end
    end
  end
end
