# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.
require 'rake'
require 'ddtrace'

require File.expand_path('../config/application', __FILE__)

if ENV['DATADOG_ENABLED'] == 'true'
  Datadog.configure do |c|
    c.use :rake, service_name: ENV['DD_SERVICE']
    c.tracer sampler: Datadog::PrioritySampler.new(
      post_sampler: Datadog::Sampling::RuleSampler.new(
          [
              # Sample all 'syncing-server' traces at 10.00%:
              Datadog::Sampling::SimpleRule.new(service: 'syncing-server', sample_rate: 0.1000)
          ]
      )
    )
  end
end

Rails.application.load_tasks
