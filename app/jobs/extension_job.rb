class ExtensionJob < ApplicationJob
  require 'net/http'
  require 'uri'

  def perform(user_id, url, extension_id, item_ids = [], force_mute = false)
    user = User.find_by_uuid(user_id)

    return if user.nil?

    items = if item_ids.length.positive?
      user.items.find(item_ids)
    else
      user.items.where(deleted: false).to_a
    end

    auth_params = user.auth_params

    settings = ExtensionSetting.find_or_create_by(extension_id: extension_id)
    mute_emails = force_mute || settings.mute_emails

    payload = {
      items: items,
      auth_params: auth_params,
      silent: mute_emails,
    }.to_json

    begin
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      req = Net::HTTP::Post.new(uri.request_uri, 'Content-Type' => 'application/json')
      req.body = payload
      http.use_ssl = (uri.scheme == 'https')
    rescue
      Rails.logger.error "Error creating extensions server request with payload: #{payload}."
      return
    end

    response = http.request(req)

    unless response.code.starts_with?('2')
      Rails.logger.warn "Failed to reach extensions server: #{response.to_json}"

      UserMailer.failed_backup(
        user_id,
        extension_id,
        settings.uuid
      ).deliver_now unless mute_emails
    end
  end
end
