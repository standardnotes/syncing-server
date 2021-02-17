require 'aws-sdk-s3'

class ExtensionJob < ApplicationJob
  require 'net/http'
  require 'uri'

  def perform(user_id, url, extension_id, item_ids = [], force_mute = false)
    if ENV['INTERNAL_DNS_REROUTE_ENABLED'] == 'true'
      url.sub! 'https://extensions.standardnotes.org', ENV['EXTENSIONS_SERVER']
    end

    Octopus.using(:slave1) do
      user = User.find_by_uuid(user_id)

      return if user.nil?

      items = if item_ids.length.positive?
        user.items.find(item_ids)
      else
        user.items.where(deleted: false).to_a
      end

      auth_params = user.key_params

      settings = ExtensionSetting.find_by_extension_id(extension_id)
      settings = ExtensionSetting.using(:master).create(extension_id: extension_id) if settings.nil?
      mute_emails = force_mute || settings.mute_emails

      tmp_file = prepare_tmp_file(auth_params, items)
      filename = upload_tmp_file_to_s3(tmp_file.path)
      tmp_file.close
      tmp_file.unlink

      payload = {
        items: items,
        backup_filename: filename,
        user_uuid: user.uuid,
        auth_params: auth_params,
        silent: mute_emails,
        settings_id: settings.uuid,
      }.to_json

      begin
        uri = URI.parse(url)
        http = Net::HTTP.new(uri.host, uri.port)
        req = Net::HTTP::Post.new(uri.request_uri, 'Content-Type' => 'application/json')
        req.body = payload
        http.use_ssl = (uri.scheme == 'https')
      rescue StandardError => e
        Rails.logger.error "Error creating extensions server request: #{e.message}"
        return
      end

      response = nil
      sent = false
      begin
        response = http.request(req)
        sent = response.code.starts_with?('2')
      rescue StandardError => e
        Rails.logger.error "Failed to send a request to extensions server: #{e.message}"
        Rails.logger.debug "Response code was #{response.code}. Body sample: #{response.body[0, 100]}" if response
      end

      unless sent
        if response
          Rails.logger.debug "Response code was #{response.code}. Body sample: #{response.body[0, 100]}. URL sent: #{url}"
        end

        UserMailer.failed_backup(
          user_id,
          extension_id,
          settings.uuid
        ).deliver_now unless mute_emails
      end
    end
  rescue StandardError => e
    Rails.logger.error "Could not perform extension job: #{e.message}"
  end

  def upload_tmp_file_to_s3(tmp_file_path)
    unless ENV['S3_BACKUP_BUCKET_NAME'] && ENV['AWS_REGION']
      Rails.logger.warn { 'S3 backup bucket not configured' }

      return nil
    end

    s3 = Aws::S3::Resource.new(region: ENV['AWS_REGION'])
    filename = SecureRandom.hex
    obj = s3.bucket(ENV['S3_BACKUP_BUCKET_NAME']).object(filename)
    obj.upload_file(tmp_file_path)

    filename
  end

  def prepare_tmp_file(auth_params, items)
    tmp = Tempfile.new(SecureRandom.hex)
    payload = { 'items' => items }
    payload['auth_params'] = auth_params unless auth_params.nil?
    tmp.write(JSON.pretty_generate(payload.as_json({})).to_s)
    tmp.rewind

    tmp
  end
end
