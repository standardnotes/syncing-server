# frozen_string_literal: true

namespace :items do
  desc 'Daily Revisions Cleanup'

  task daily_revisions_cleanup: :environment do
    revisions_retention_days = ENV['REVISIONS_RETENTION_DAYS'] ? ENV['REVISIONS_RETENTION_DAYS'].to_i : 30

    Octopus.using(:slave1) do
      total_count = Item.count

      Rails.logger.info "Cleaning up revisions for all items. Total items count: #{total_count}"

      Item.find_in_batches.with_index do |group, batch|
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
