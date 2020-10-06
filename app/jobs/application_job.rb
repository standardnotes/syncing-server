require 'get_process_mem'

class ApplicationJob < ActiveJob::Base
  queue_as ENV['SQS_QUEUE'] || (Rails.env.production? ? 'sn_main' : 'dev_queue')
end
