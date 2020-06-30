class Admin::AdminController < ApplicationController
  before_action do
    admin_key = params[:admin_key]
    env_admin_key = ENV['ADMIN_KEY']
    if !admin_key || !env_admin_key || !ActiveSupport::SecurityUtils.secure_compare(admin_key, env_admin_key)
      render json: {}, status: 401
    end
  end

  respond_to :json

  def delete_account
    email = params[:email]
    user = User.find_by_email email
    if user
      user.items.destroy_all
      user.delete
    end

    render json: {}, status: 200
  end
end
