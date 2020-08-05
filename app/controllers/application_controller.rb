class ApplicationController < ActionController::API
  respond_to :json

  def route_not_found
    render 'error_pages/404', status: :not_found
  end

  def home
    render json: {
      message: "Hi! You're not supposed to be here."
    }, status: :ok
  end

  protected

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
