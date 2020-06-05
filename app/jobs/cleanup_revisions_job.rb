class CleanupRevisionsJob < ApplicationJob
  MAX_REVISIONS_PER_DAY = 30
  MIN_REVISIONS_PER_DAY = 2

  def perform(item_id, days)
    item = Item.find(item_id)

    last_days_of_revisions = item.revisions
      .select('created_at')
      .order('created_at DESC')
      .group_by { |x| x.created_at.strftime('%Y-%m-%d') }
      .take(30)

    days_to_process = []
    last_days_of_revisions.each do |day, _revisions|
      days_to_process.push(day)
    end

    days_to_process.each do |day|
      days_from_today = (DateTime.now - day.to_date).to_i
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
        .where(created_at: date.midnight..date.end_of_day)
        .where.not(uuid: revisions_to_keep)
        .destroy_all
    end
  end
end
