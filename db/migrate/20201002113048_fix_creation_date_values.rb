class FixCreationDateValues < ActiveRecord::Migration[5.1]
  def change
    execute 'UPDATE revisions SET creation_date = created_at'
  end
end
