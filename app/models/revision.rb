class Revision < ApplicationRecord
  has_many :item_revisions, foreign_key: 'revision_uuid', dependent: :destroy
  has_many :items, through: :item_revisions

  def serializable_hash(options = {})
    allowed_options = [
      'auth_hash',
      'content_type',
      'content',
      'created_at',
      'creation_date',
      'enc_item_key',
      'item_uuid',
      'items_key_id',
      'updated_at',
      'uuid',
    ]

    super(options.merge(only: allowed_options))
  end
end
