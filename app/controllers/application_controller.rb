class ApplicationController < ActionController::Base
  protect_from_forgery with: :null_session
  after_action :set_csrf_cookie
  respond_to :html, :json
  layout :false

  def route_not_found
    render 'error_pages/404', status: :not_found
  end

  protected

  def set_csrf_cookie
    cookies['XSRF-TOKEN'] = form_authenticity_token if protect_against_forgery?
  end

  def append_info_to_payload(payload)
    super

    unless payload[:status]
      return
    end

    payload[:level] = 'INFO'
    if payload[:status] >= 500
      payload[:level] = 'ERROR'
    elsif payload[:status] >= 400
      payload[:level] = 'WARN'
    end
  end
end
