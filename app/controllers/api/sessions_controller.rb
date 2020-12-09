class Api::SessionsController < Api::ApiController
  skip_before_action :authenticate_user, only: [:refresh]
  before_action :require_valid_session, except: [:refresh]

  def index
    Rails.logger.warn 'DEPRECATED: further development in https://github.com/standardnotes/syncing-server-js'

    sessions = current_user.active_sessions.to_a.map(&:serializable_hash)
    sessions.each { |session| session[:current] = current_session.uuid == session['uuid'] }

    render json: sessions
  end

  def delete
    Rails.logger.warn 'DEPRECATED: further development in https://github.com/standardnotes/syncing-server-js'

    unless params[:uuid]
      render json: {
        error: {
          message: 'Please provide the session identifier.',
        },
      },
      status: :bad_request
      return
    end

    if params[:uuid] == current_session.uuid
      render json: {
        error: {
          message: 'You can not delete your current session.',
        },
      }, status: :bad_request
      return
    end

    session = current_user.sessions.find_by_uuid(params[:uuid])

    unless session
      render json: {
        error: {
          message: 'No session exists with the provided identifier.',
        },
      }, status: :bad_request
      return
    end

    session.destroy

    render json: {}, status: :no_content
  end

  def delete_all
    Rails.logger.warn 'DEPRECATED: further development in https://github.com/standardnotes/syncing-server-js'

    current_user.sessions.where.not(uuid: current_session.uuid).destroy_all
    render json: {}, status: :no_content
  end

  def refresh
    Rails.logger.warn 'DEPRECATED: further development in https://github.com/standardnotes/syncing-server-js'

    if !params[:access_token] || !params[:refresh_token]
      render json: {
        error: {
          message: 'Please provide all required parameters.',
        },
      }, status: :bad_request
      return
    end

    session = Session.from_token(params[:access_token])

    if session.nil?
      render json: {
        error: {
          tag: 'invalid-parameters',
          message: 'The provided parameters are not valid.',
        },
      }, status: :bad_request
      return
    end

    unless session.valid_refresh_token?(params[:refresh_token])
      render json: {
        error: {
          tag: 'invalid-refresh-token',
          message: 'The refresh token is not valid.',
        },
      }, status: :bad_request
      return
    end

    access_token, refresh_token = session.renew

    unless access_token
      render json: {
        error: {
          tag: 'expired-refresh-token',
          message: 'The refresh token has expired.',
        },
      }, status: :bad_request
      return
    end

    render json: {
      session: session.as_client_payload(access_token, refresh_token),
    }
  end

  private

  def require_valid_session
    if current_session.nil?
      render_unsupported_account_version
    end
  end

  def render_unsupported_account_version
    render json: {
      error: {
        tag: 'unsupported-account-version',
        message: 'Account version not supported.',
      },
    }, status: :bad_request
  end
end
