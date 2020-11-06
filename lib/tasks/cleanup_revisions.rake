# frozen_string_literal: true

namespace :items do
  desc 'Cleanup revisions'

  task cleanup_revisions: :environment do
    revisions_retention_days = ENV['REVISIONS_RETENTION_DAYS'] ? ENV['REVISIONS_RETENTION_DAYS'].to_i : 30
    revisions_cleanup_frequency = ENV['REVISIONS_CLEANUP_FREQUENCY'] ? ENV['REVISIONS_CLEANUP_FREQUENCY'].to_i : 60

    Octopus.using(:slave1) do
      period_start = revisions_cleanup_frequency.minutes.ago
      period_end = DateTime.now
      query = Item.where('updated_at > ? AND updated_at < ?', period_start, period_end)
      total_count = query.count

      Rails.logger.info "Cleaning up revisions from items updated between #{period_start} and #{period_end}." \
        "Total items count: #{total_count}"

      query.find_in_batches.with_index do |group, batch|
        Rails.logger.info "Processing batch #{batch}"
        Rails.logger.flush

        group.each do |item|
          begin
            item.cleanup_revisions(revisions_retention_days)
          rescue StandardError => e
            Rails.logger.error "Could not clean up revisions for item #{item.uuid}: #{e.message}"
          end
        end
      end
      Rails.logger.info 'Items successfully cleaned up'
    end
  end
end
