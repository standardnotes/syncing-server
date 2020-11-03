# frozen_string_literal: true

namespace :items do
  desc 'Cleanup revisions'

  task cleanup_revisions: :environment do
    revisions_retention_days = ENV['REVISIONS_RETENTION_DAYS'] ? ENV['REVISIONS_RETENTION_DAYS'].to_i : 30

    Octopus.using(:slave1) do
      Item.where('updated_at >= ?', 1.hour.ago).find_in_batches.with_index do |group, batch|
        Rails.logger.info "Cleaning up revisions for items. Batch ##{batch}"

        group.each do |item|
          item.cleanup_revisions(revisions_retention_days)
        end
      end
    end
  end
end
