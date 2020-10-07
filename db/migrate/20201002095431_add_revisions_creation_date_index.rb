class AddRevisionsCreationDateIndex < ActiveRecord::Migration[5.1]
  def change
    add_column :revisions, :creation_date, :date, after: :auth_hash
    add_index :revisions, [:creation_date], algorithm: :inplace
  end
end
