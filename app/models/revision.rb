class Revision < ApplicationRecord
  has_many :item_revisions, foreign_key: 'revision_uuid', dependent: :destroy
  has_many :items, through: :item_revisions

  def serializable_hash(options = {})
    allowed_options = [
      'uuid',
      'items_key_id',
      'duplicate_of',
      'enc_item_key',
      'content',
      'content_type',
      'auth_hash',
      'deleted',
      'created_at',
      'updated_at',
    ]

    super(options.merge(only: allowed_options)).merge({
      revision_uuid: uuid,
      uuid: item_ids.first,
    })
  end
end
