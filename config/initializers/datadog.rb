if ENV['DATADOG_ENABLED'] == 'true'
  Datadog.configure do |c|
    # This will activate auto-instrumentation for Rails
    c.use :rails, { 'service_name' => 'syncing-server' }
  end
end
