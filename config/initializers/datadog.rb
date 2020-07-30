if ENV['DATADOG_ENABLED'] == 'true'
  Datadog.configure do |c|
    c.use :rails,
          {
            'service_name' => 'syncing-server',
            'controller_service' => 'syncing-server',
            'database_service' => 'syncing-server-mysql'
          }
  end
end
