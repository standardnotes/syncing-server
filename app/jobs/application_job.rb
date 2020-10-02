require 'get_process_mem'

class ApplicationJob < ActiveJob::Base
  queue_as ENV['SQS_QUEUE'] || (Rails.env.production? ? 'sn_main' : 'dev_queue')

  before_perform do
    mb = GetProcessMem.new.mb
    Rails.logger.info "[#{name}] BEFORE_PERFORM - MEMORY USAGE(MB): #{mb.round}"
  end

  after_perform do
    mb = GetProcessMem.new.mb
    Rails.logger.info "[#{name}] AFTER_PERFORM - MEMORY USAGE(MB): #{mb.round}"
  end

  def name
    self.class.name.demodulize
  end
end
