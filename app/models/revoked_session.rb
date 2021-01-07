class RevokedSession < ApplicationRecord
  replicated_model

  belongs_to :user, foreign_key: 'user_uuid'

  def self.from_token(request_token)
    _version, session_id, _access_token = Session.deconstruct_token(request_token)

    RevokedSession.find_by_uuid(session_id)
  end
end
