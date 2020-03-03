class ApplicationController < ActionController::Base
  protect_from_forgery with: :null_session
  after_action :set_csrf_cookie
  respond_to :html, :json
  layout :false

  protected

  def set_csrf_cookie
    cookies['XSRF-TOKEN'] = form_authenticity_token if protect_against_forgery?
  end
end
