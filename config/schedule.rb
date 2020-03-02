# Use this file to easily define all of your cron jobs.

set :output, 'log/whenever.log'

# UTC Time, 4am UTC => 11pm CT (DST: -5 offset, otherwise -6 offset)
every 1.day, at: '5:00 am' do
  rake "items:perform_daily_backup_jobs"
end
