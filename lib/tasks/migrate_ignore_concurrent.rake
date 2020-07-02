# https://nebulab.it/blog/the-strange-case-of-activerecord-concurrentmigrationerror/

namespace :db do
  namespace :migrate do
    desc 'Run db:migrate but ignore ActiveRecord::ConcurrentMigrationError errors'
    task ignore_concurrent: :environment do
      begin
        Rake::Task['db:migrate'].invoke
      rescue ActiveRecord::ConcurrentMigrationError
        # Do nothing
      end
    end
  end
end
