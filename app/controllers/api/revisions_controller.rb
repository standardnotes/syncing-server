# DEPRECATED: Further development in https://github.com/standardnotes/syncing-server-js
class Api::RevisionsController < Api::ApiController
  def show
    begin
      item = current_user.items.find(params[:item_id])
    rescue ActiveRecord::RecordNotFound
      return render json: { error: { message: 'Item not found' } }, status: :not_found
    end

    revision = item.revisions
      .where(uuid: params[:id])
      .select('revisions.*')
      .order(created_at: :desc)
      .first

    render json: revision
  end

  def index
    begin
      item = current_user.items.find(params[:item_id])
    rescue ActiveRecord::RecordNotFound
      return render json: { error: { message: 'Item not found' } }, status: :not_found
    end

    revisions_retention_days = ENV['REVISIONS_RETENTION_DAYS'] ? ENV['REVISIONS_RETENTION_DAYS'].to_i : 30

    revisions = item.revisions
      .where(created_at: revisions_retention_days.days.ago..DateTime::Infinity.new)
      .select('revisions.uuid, content_type, created_at, updated_at')
      .order(created_at: :desc)

    render json: revisions
  end
end
