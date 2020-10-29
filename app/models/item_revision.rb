class ItemRevision < ApplicationRecord
  belongs_to :item, foreign_key: 'item_uuid'
  belongs_to :revision, foreign_key: 'revision_uuid'
end
