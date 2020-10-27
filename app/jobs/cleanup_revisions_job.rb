class CleanupRevisionsJob < ApplicationJob
  distribute_reads(max_lag: ENV['DB_REPLICA_MAX_LAG'], lag_failover: ENV['DB_REPLICA_LAG_FAILOVER'] || true)

  queue_as ENV['SQS_QUEUE_LOW_PRIORITY'] || 'sn_main_low_priority'

  MAX_REVISIONS_PER_DAY = 30
  MIN_REVISIONS_PER_DAY = 2

  def perform(item_id, days)
    item = Item.find_by_uuid(item_id)

    unless item
      Rails.logger.warn "Could not find item with uuid #{item_id}"

      return
    end

    last_days_of_revisions = item.revisions
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
      cleanup_revisions_for_a_day(item, days_from_today, allowed_revisions_count)
    end
  rescue StandardError => e
    Rails.logger.error "Could not cleanup revisions for item #{item_id}: #{e.message}"
  end

  def cleanup_revisions_for_a_day(item, days_from_today, allowed_revisions_count)
    date = Time.now.utc.to_date - days_from_today
    revisions_from_date_count = item.revisions.where(creation_date: date).count

    if revisions_from_date_count > allowed_revisions_count
      revisions_from_date = item.revisions
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
        .where(item_uuid: item.uuid)
        .where(creation_date: date)
        .where.not(uuid: revisions_to_keep)
        .delete_all

      ItemRevision
        .where(item_uuid: item.uuid)
        .where(revision_uuid: revisions_from_date.difference(revisions_to_keep))
        .delete_all
    end
  end
end
