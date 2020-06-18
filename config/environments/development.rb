Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  config.middleware.delete Rack::Lock

  # config.file_watcher = ActiveSupport::EventedFileUpdateChecker

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false
  config.reload_classes_only_on_change = true

  config.logger = ActiveSupport::Logger.new(config.paths['log'].first, 1, 1 * 1024 * 1024)

  require 'custom_log_formatter'
  config.log_formatter = CustomLogFormatter.new
  config.logger.formatter = config.log_formatter

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = true

  # config.public_file_server.enabled = true

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations.
  # config.active_record.migration_error = :page_load

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = true

  # Asset digests allow you to set far-future HTTP expiration dates on all assets,
  # yet still be able to expire them through the digest params.
  config.assets.digest = true

  # Adds additional error checking when serving assets at runtime.
  # Checks for improperly declared sprockets dependencies.
  # Raises helpful error messages.
  config.assets.raise_runtime_errors = true

  config.active_job.queue_adapter = :inline
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true

  config.action_mailer.smtp_settings = {
    :address => ENV['SMTP_HOST'],
    :port => ENV['SMTP_PORT'],
  }

  # Raises error for missing translations
  # config.action_view.raise_on_missing_translations = true
  config.file_watcher = ActiveSupport::EventedFileUpdateChecker
end
