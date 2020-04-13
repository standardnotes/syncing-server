require_relative 'boot'
require 'rails/all'
Bundler.require(*Rails.groups)

module StandardNotes
  class Application < Rails::Application
    config.load_defaults 5.1
    config.autoload_once_paths += Dir["#{config.root}/lib/**/*"]
    config.active_record.primary_key = :uuid

    Shoryuken.logger.level = Logger::FATAL
    config.active_job.queue_adapter = :shoryuken
    config.action_mailer.deliver_later_queue_name = ENV['SQS_QUEUE'] || 'dev_queue'

    raven_dsn = ENV["RAVEN_DSN"]
    if raven_dsn
      Raven.configure do |config|
        config.dsn = raven_dsn
        config.sanitize_fields = Rails.application.config.filter_parameters.map(&:to_s)
        config.environments = ['staging', 'production']
      end
    end

    # Cross-Origin Resource Sharing (CORS) for Rack compatible web applications.
    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins '*'
        resource '*',
          :headers => :any,
          :methods => [:get, :post, :put, :patch, :delete, :options],
          :expose => ['Access-Token', 'Client', 'UID']
      end
    end

    SecureHeaders::Configuration.default do |config|
      # Handled by nginx server
      config.x_frame_options = SecureHeaders::OPT_OUT
      config.x_content_type_options = SecureHeaders::OPT_OUT
      config.x_xss_protection = SecureHeaders::OPT_OUT
      config.hsts = SecureHeaders::OPT_OUT

      config.csp = {
         preserve_schemes: true,
         default_src: %w(https: 'self'),
         base_uri: %w('self'),
         block_all_mixed_content: false,
         child_src: ["*", "blob:"],
         frame_src: ["*", "blob:"],
         connect_src: ["*"],
         font_src: %w(* 'self'),
         form_action: %w('self'),
         frame_ancestors: ["*", "*.standardnotes.org"],
         img_src: %w('self' * data:),
         manifest_src: %w('self'),
         media_src: %w('self'),
         object_src: %w('self'),
         plugin_types: %w(),
         script_src: %w('self'),
         style_src: %w('self'),
         upgrade_insecure_requests: false,
      }
    end

    config.generators do |g|
      g.orm :active_record, primary_key_type: :uuid
    end

    config.middleware.insert_before(Rack::Sendfile, Rack::Deflater)

    # Disable auto creation of additional resources with "rails generate"
    config.generators do |g|
      g.test_framework false
      g.view_specs false
      g.helper_specs false
      g.stylesheets = false
      g.javascripts = false
      g.helper = false
    end

    config.action_mailer.default_url_options = { host: ENV['HOST'] }

    # SMTP settings
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      :address => ENV['SMTP_HOST'],
      :port => ENV['SMTP_PORT'],
      :domain => ENV['SMTP_DOMAIN'],
      :user_name => ENV['SMTP_USERNAME'],
      :password => ENV['SMTP_PASSWORD'],
      :authentication => 'login',
      :enable_starttls_auto => true # detects and uses STARTTLS
    }

    # Custom configuration
    config.x.auth = config_for(:sn_auth).symbolize_keys
    config.x.session = config_for(:sn_session).symbolize_keys
  end
end
