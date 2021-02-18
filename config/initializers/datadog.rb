if ENV['DATADOG_ENABLED'] == 'true'
  Datadog.configure do |c|
    c.use :rails
    c.use :shoryuken, service_name: 'syncing-server-worker'
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
