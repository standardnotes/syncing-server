require 'mysql2/reconnect_with_readonly'

class ApplicationJob < ActiveJob::Base
  queue_as ENV['SQS_QUEUE'] || (Rails.env.production? ? 'sn_main' : 'dev_queue')
end
