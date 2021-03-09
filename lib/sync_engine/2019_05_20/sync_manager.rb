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
        last_updated = (last_updated.to_time + 1 / 1_000_000.0).to_datetime.utc
        sync_token = sync_token_from_datetime(last_updated)

        {
          retrieved_items: retrieved_items,
          saved_items: saved_items,
          conflicts: conflicts,
          sync_token: sync_token,
          cursor_token: cursor_token,
        }
      end

      # Do not create conflicts for differences that are MIN_CONFLICT_INTERVAL_MICROSECONDS apart,
      # instead just saving directly and overwriting server value.
      # JavaScript only supports timestamps in milliseconds (3 decimal places), whereas we save timestamps
      # in microseconds (6 decimal places). Any changes made <= 1 millisecond apart will not be treated as a conflict.
      MIN_CONFLICT_INTERVAL_MICROSECONDS = 1_000
      MICROSECONDS_IN_SEC = 1_000_000

      def _sync_save(item_hashes, request, retrieved_items)
        unless item_hashes
          return [], []
        end

        saved_items = []
        conflicts = []

        item_hashes.each do |item_hash|
          item = @user.items.find_by(uuid: item_hash[:uuid])

          # SFJS did not send updated_at prior to 0.3.59.
          # updated_at value from client will not be saved, as it is not a permitted_param.
          incoming_updated_at = if item_hash['updated_at']
            DateTime.parse(item_hash['updated_at'])
          else
            # Default to epoch
            Time.at(0).to_datetime
          end

          if item
            # We want to check if the incoming updated_at value is equal to the item's current updated_at value.
            # If they differ, it means the client is attempting to save an item which doesn't have the correct server value.
            # We conflict if the difference in dates is greater than the 1 unit of precision (MIN_CONFLICT_INTERVAL_MICROSECONDS)

            our_updated_at = item.updated_at
            difference_microseconds = (incoming_updated_at.to_f - our_updated_at.to_f) * MICROSECONDS_IN_SEC

            save_incoming = if difference_microseconds < 0
              # incoming is less than ours. This implies stale data. Don't save if greater than interval
              difference_microseconds.abs < MIN_CONFLICT_INTERVAL_MICROSECONDS
            elsif difference_microseconds > 0
              # incoming is greater than ours. Should never be the case. If so though, don't save.
              difference_microseconds.abs < MIN_CONFLICT_INTERVAL_MICROSECONDS
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

          if !item
            item = @user.items.new({ uuid: item_hash[:uuid] }.merge(item_params(item_hash)))
            item.last_user_agent = request.user_agent
            begin
              item.save
            rescue
              conflicts.push(
                unsaved_item: item_hash,
                type: 'uuid_conflict',
              )
              next
            end
          else
            item.last_user_agent = request.user_agent
            item.update(item_params(item_hash))
          end

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
          # Note that we don't add 1 microsecond to the date here like we do for the sync_token.
          # This is because some items may have the exact same updated_at value, like when
          # initially saving a large amount of imported data. Adding 1 microsecond here
          # would make us miss these items on subsequent pages.
          cursor_token = sync_token_from_datetime(date)
        end

        [items, cursor_token]
      end
    end
  end
end
