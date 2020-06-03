class Revision < ApplicationRecord
  has_many :item_revisions, foreign_key: 'revision_uuid'
  has_many :items, through: :item_revisions
end
