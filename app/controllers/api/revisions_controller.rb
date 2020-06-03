class Api::RevisionsController < Api::ApiController
  def show
    revision = current_user.items.find(params[:item_id]).revisions.find(params[:id])

    render json: revision
  end

  def index
    item = current_user.items.where(uuid: params[:item_id]).first

    render json: item.get_revision_history(User::REVISIONS_RETENTION_DAYS)
  end
end
