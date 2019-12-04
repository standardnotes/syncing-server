require 'rails_helper'

RSpec.describe User, type: :model do
  context "with a User class" do
    
    it "can hash a password" do
      p = User.hash_password("test")

      expect(p).not_to eql("test")
    end

    it "can check a password hash" do
      p = User.hash_password("test")
      check = User.test_password("test", p)

      expect(check).to eql(true)
    end

    it "creates a different hash for different users" do
      p = User.hash_password("test")
      p2 = User.hash_password("test")

      expect(p).not_to eql(p2)
    end

    it "validates same passwords for different users" do
      p = User.hash_password("test")
      p2 = User.hash_password("test")

      check1 = User.test_password("test", p)
      expect(check1).to eql(true)

      check2 = User.test_password("test", p2)
      expect(check2).to eql(true)
    end
  end

  context "with a single user" do
    it "orders items chronologically" do
      u = User.create!
      item1 = u.items.create!
      sleep(1)
      item2 = u.items.create!
      expect(u.reload.items).to eq([item2, item1])
    end
  end

end
