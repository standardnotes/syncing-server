# https://nebulab.it/blog/the-strange-case-of-activerecord-concurrentmigrationerror/

namespace :db do
  namespace :migrate do
    desc 'Run db:migrate but ignore ActiveRecord::ConcurrentMigrationError errors'
    task ignore_concurrent: :environment do
      migrated = false
      until migrated
        begin
          Rake::Task['db:migrate'].invoke
          migrated = true
        rescue ActiveRecord::ConcurrentMigrationError
          Rails.logger.error 'Concurrent migration rescued. Sleeping 10s before another attempt'
          sleep 10
        end
      end
    end
  end
end
