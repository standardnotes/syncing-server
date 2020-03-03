class RegistrationJob < ApplicationJob
  require 'net/http'
  require 'uri'

  def perform(user_email, created_at_string)
    uri = URI.parse("#{ENV['USER_MANAGEMENT_SERVER']}/admin/events/registration")
    http = Net::HTTP.new(uri.host, uri.port)
    req = Net::HTTP::Post.new(uri.request_uri, 'Content-Type' => 'application/json')
    params = {
      key: ENV['USER_MANAGEMENT_KEY'],
      user: {
        email: user_email,
        created_at: created_at_string.to_datetime,
      },
    }
    req.body = params.to_json
    http.use_ssl = (uri.scheme == 'https')
    http.request(req)
  end
end
