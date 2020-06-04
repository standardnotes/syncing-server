class CleanupRevisionsJob < ApplicationJob
  MAX_REVISIONS_PER_DAY = 30
  MIN_REVISIONS_PER_DAY = 2

  def perform(item_id, days)
    item = Item.find(item_id)

    days.times do |days_from_today|
      allowed_revisions_count = [[days - days_from_today, MAX_REVISIONS_PER_DAY].min, MIN_REVISIONS_PER_DAY].max
      cleanup_revisions_for_a_day(item, days_from_today, allowed_revisions_count)
    end
  end

  def cleanup_revisions_for_a_day(item, days_from_today, allowed_revisions_count)
    date = Time.now.utc.to_date - days_from_today
    revisions_from_date_count = item.revisions.where(created_at: date.midnight..date.end_of_day).size

    if revisions_from_date_count > allowed_revisions_count
      revisions_from_date = item.revisions
        .where(created_at: date.midnight..date.end_of_day)
        .order(created_at: :desc)
        .pluck(:uuid)

      revisions_slice_size = (revisions_from_date.length.to_f / allowed_revisions_count).floor
      revisions_to_keep = revisions_from_date
        .each_slice(revisions_slice_size)
        .map(&:last)
        .last(allowed_revisions_count)

      Revision
        .where(created_at: date.midnight..date.end_of_day)
        .where.not(uuid: revisions_to_keep)
        .destroy_all
    end
  end
end
