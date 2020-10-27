class Api::RevisionsController < Api::ApiController
  def show
    distribute_reads(
      max_lag: ENV['DB_REPLICA_MAX_LAG'] ? ENV['DB_REPLICA_MAX_LAG'].to_i : nil,
      lag_failover: ENV['DB_REPLICA_LAG_FAILOVER'] ? ActiveModel::Type::Boolean.new.cast(ENV['DB_REPLICA_LAG_FAILOVER']) : true
    ) do
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
    distribute_reads(
      max_lag: ENV['DB_REPLICA_MAX_LAG'] ? ENV['DB_REPLICA_MAX_LAG'].to_i : nil,
      lag_failover: ENV['DB_REPLICA_LAG_FAILOVER'] ? ActiveModel::Type::Boolean.new.cast(ENV['DB_REPLICA_LAG_FAILOVER']) : true
    ) do
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
