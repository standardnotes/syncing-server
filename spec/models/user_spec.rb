require 'rails_helper'

RSpec.describe User, type: :model do
  subject {
    described_class.new(pw_cost: 11000, version: "003", email: "sn@testing.com")
  }

  describe "serializable_hash" do
    let(:hash) {
      subject.serializable_hash
    }

    let(:hash_keys) {
      ["uuid", "email"].sort
    }

    specify do
      expect(hash.count).to eq 2
      expect(hash.keys.sort).to contain_exactly(*hash_keys)
    end
  end

  describe "auth_params" do
    specify do
      auth_params = subject.auth_params
      expect(auth_params.keys).to contain_exactly(:pw_cost, :version, :identifier)
    end

    specify do
      subject.pw_nonce = "some nonce"

      auth_params = subject.auth_params
      expect(auth_params.keys).to contain_exactly(:pw_cost, :version, :identifier, :pw_nonce)
    end

    specify do
      subject.pw_salt = "some salt"

      auth_params = subject.auth_params
      expect(auth_params.keys).to contain_exactly(:pw_cost, :version, :identifier, :pw_salt)
    end

    specify do
      subject.pw_func = "some function"

      auth_params = subject.auth_params
      expect(auth_params.keys).to contain_exactly(:pw_cost, :version, :identifier, :pw_func, :pw_alg, :pw_key_size)
    end
  end

  describe "bytes_to_megabytes" do
    specify do
      expect(subject.bytes_to_megabytes(1000000)).to eq "0.95MB"
    end
  end
end
