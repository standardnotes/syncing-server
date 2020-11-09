# frozen_string_literal: true

namespace :items do
  desc 'Daily Revisions Cleanup'

  task daily_revisions_cleanup: :environment do
    revisions_retention_days = ENV['REVISIONS_RETENTION_DAYS'] ? ENV['REVISIONS_RETENTION_DAYS'].to_i : 30

    Octopus.using(:slave1) do
      period_start = revisions_retention_days.days.ago
      period_end = DateTime.now
      Rails.logger.info "Daily cleanup for revisions from items updated between #{period_start} and #{period_end}"
      counter = 0
      Item.where('updated_at > ? AND updated_at < ?', period_start, period_end).find_each do |item|
        begin
          item.cleanup_revisions(revisions_retention_days)
          counter += 1
        rescue StandardError => e
          Rails.logger.error "Could not clean up revisions for item #{item.uuid}: #{e.message}"
        end
      end
      Rails.logger.info "Number of items cleaned up: #{counter}"
    end
  end
end
