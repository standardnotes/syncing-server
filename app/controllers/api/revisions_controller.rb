class Api::RevisionsController < Api::ApiController
  def show
    distribute_reads do
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
  end

  def index
    distribute_reads do
      begin
        item = current_user.items.find(params[:item_id])
      rescue ActiveRecord::RecordNotFound
        return render json: { error: { message: 'Item not found' } }, status: :not_found
      end

      revisions = item.revisions
        .where(created_at: User::REVISIONS_RETENTION_DAYS.days.ago..DateTime::Infinity.new)
        .select('revisions.uuid, content_type, created_at, updated_at')
        .order(created_at: :desc)

      render json: revisions
    end
  end
end
