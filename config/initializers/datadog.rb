if ENV['DATADOG_ENABLED'] == 'true'
  Datadog.configure do |c|
    c.use :rails
  end
end
