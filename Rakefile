# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.
require 'rake'
require 'ddtrace'

require File.expand_path('../config/application', __FILE__)

if ENV['DATADOG_ENABLED'] == 'true'
  Datadog.configure do |c|
    c.use :rake, service_name: ENV['DD_SERVICE']
  end
end

Rails.application.load_tasks
