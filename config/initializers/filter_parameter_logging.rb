# Be sure to restart your server when you modify this file.

# Configure sensitive parameters which will be filtered from the log file.
Rails.application.config.filter_parameters += [:password, :content, :enc_item_key, :auth_hash, :admin_key, :items]
