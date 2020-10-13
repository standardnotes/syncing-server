if ENV['DATADOG_ENABLED'] == 'true'
  Datadog.configure do |c|
    c.use :rails
    c.use :shoryuken, service_name: 'syncing-server-worker'
  end
end
