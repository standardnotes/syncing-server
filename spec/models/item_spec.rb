require 'rails_helper'

RSpec.describe Item, type: :model do
  context "with an Item class" do

    u = User.create!
    u2 = User.create!
    i = u.items.create!
    i2 = u2.items.create!

    it "belongs to a user" do
      expect(u.uuid).to eql(i.user_uuid)
      expect(u2.uuid).to eql(i2.user_uuid)
    end

    it "has a serializable hash" do
      hash = i.serializable_hash
      expect(hash.is_a?(Hash)).to eql(true)
    end

    it "can be set as deleted" do
      i.set_deleted
      expect(i.deleted).to eql(true)
    end
  end
end
