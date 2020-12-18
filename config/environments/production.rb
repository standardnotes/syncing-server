Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Overwrite queue name from application.rb
  config.action_mailer.deliver_later_queue_name = ENV['SQS_QUEUE'] || 'sn_main'

  # Code is not reloaded between requests.
  config.cache_classes = true
  MAX_LOG_MEGABYTES = 50
  config.logger = ActiveSupport::Logger.new(config.paths['log'].first, 1, MAX_LOG_MEGABYTES * 1024 * 1024)

  if ENV["RAILS_LOG_TO_STDOUT"].present?
    config.logger = ActiveSupport::Logger.new(STDOUT)
  end

  config.log_level = ENV.fetch('RAILS_LOG_LEVEL', 'info').to_sym

  config.colorize_logging = false
  config.logger.formatter = StandardNotesFormatter.new

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?

  # Do not fallback to assets pipeline if a precompiled asset is missed.
  config.assets.compile = false

  # Asset digests allow you to set far-future HTTP expiration dates on all assets,
  # yet still be able to expire them through the digest params.
  config.assets.digest = true

  config.assets.logger = false
  config.assets.quiet = true

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  config.action_mailer.raise_delivery_errors = true

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners.
  config.active_support.deprecation = :notify
end
