require 'rails_helper'

RSpec.describe Item, type: :model do
  subject {
    described_class.new
  }

  it "should be marked as deleted" do
    subject.mark_as_deleted
    expect(subject.deleted).to be true
    expect(subject.content).to be_nil
    expect(subject.enc_item_key).to be_nil
    expect(subject.auth_hash).to be_nil
  end

  describe "serializable_hash" do
    let(:hash) {
      subject.serializable_hash
    }

    let(:hash_keys) {
      ["uuid", "auth_hash", "content", "content_type", "created_at", "deleted", "enc_item_key", "updated_at"].sort
    }

    specify do
      expect(hash.count).to eq 8
      expect(hash.keys.sort).to contain_exactly(*hash_keys)
    end
  end

  describe "decoded_content" do
    let(:valid_content) {
      data = { test: "hello world!" }
      "---#{Base64.encode64(JSON.dump(data))}"
    }

    it "should return nil if content is nil" do
      subject.content = nil
      expect(subject.decoded_content).to be_nil
    end

    it "should return nil if content is not base64 encoded" do
      subject.content = "test"
      expect(subject.decoded_content).to be_nil
    end

    it "should return decoded content" do
      subject.content = valid_content
      expect(subject.decoded_content).to_not be_nil
    end
  end

  describe "is_daily_backup_extension" do
    let(:valid_content) {
      data = { frequency: "daily" }
      "---#{Base64.encode64(JSON.dump(data))}"
    }

    let(:invalid_content) {
      "---#{Base64.encode64(JSON.dump("data"))}"
    }

    specify do
      subject.content_type = "Note"
      subject.content = nil
      expect(subject.is_daily_backup_extension).to be false

      subject.content_type = "SF|Extension"
      subject.content = valid_content
      expect(subject.is_daily_backup_extension).to be true

      subject.content = invalid_content
      expect(subject.is_daily_backup_extension).to be false
    end
  end

  describe "perform_associated_job" do
    let(:invalid_content) {
      data = { test: "hello world!" }
      "---#{Base64.encode64(JSON.dump(data))}"
    }

    let(:backup_email_archive_content) {
      data = { subtype: "backup.email_archive" }
      "---#{Base64.encode64(JSON.dump(data))}"
    }

    let(:perform_later_content) {
      data = { frequency: "daily", url: "http://test.com" }
      "---#{Base64.encode64(JSON.dump(data))}"
    }

    specify do
      subject.content = invalid_content
      expect(subject.perform_associated_job).to be_nil

      subject.content = backup_email_archive_content
      expect(subject.perform_associated_job).to receive(:backup_data)

      subject.content = perform_later_content
      expect(subject.perform_associated_job).to receive(:perform_later)
    end
  end
end
