class Api::RevisionsController < Api::ApiController
  def show
    revision = current_user.items.find(params[:item_id]).revisions.find(params[:id])

    render json: revision
  end

  def index
    begin
      item = current_user.items.find(params[:item_id])
    rescue ActiveRecord::RecordNotFound
      return render json: { error: 'Item not found' }, status: :not_found
    end

    render json: item.revisions.where(created_at: User::REVISIONS_RETENTION_DAYS.days.ago..DateTime::Infinity.new)
  end
end
