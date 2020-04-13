require 'rails_helper'

RSpec.describe Item, type: :model do
  subject do
    described_class.new
  end

  it 'should be marked as deleted' do
    subject.mark_as_deleted
    expect(subject.deleted).to be true
    expect(subject.content).to be_nil
    expect(subject.enc_item_key).to be_nil
    expect(subject.auth_hash).to be_nil
  end

  describe 'serializable_hash' do
    let(:hash) do
      subject.serializable_hash
    end

    let(:hash_keys) do
      %w[uuid auth_hash content content_type created_at deleted enc_item_key updated_at items_key_id].sort
    end

    specify do
      expect(hash.count).to eq hash_keys.count
      expect(hash.keys.sort).to contain_exactly(*hash_keys)
    end
  end

  describe 'decoded_content' do
    let(:valid_content) do
      data = { test: 'hello world!' }
      "002#{Base64.encode64(JSON.dump(data))}"
    end

    it 'should return nil if content is nil' do
      subject.content = nil
      expect(subject.decoded_content).to be_nil
    end

    it 'should return nil if content is not base64 encoded' do
      subject.content = 'test'
      expect(subject.decoded_content).to be_nil
    end

    it 'should return decoded content' do
      subject.content = valid_content
      expect(subject.decoded_content).to_not be_nil
    end
  end

  describe 'daily_backup_extension' do
    let(:valid_content) do
      data = { frequency: 'daily' }
      "002#{Base64.encode64(JSON.dump(data))}"
    end

    let(:invalid_content) do
      "002#{Base64.encode64(JSON.dump('data'))}"
    end

    specify do
      subject.content_type = 'Note'
      subject.content = nil
      expect(subject.daily_backup_extension?).to be false

      subject.content_type = 'SF|Extension'
      subject.content = valid_content
      expect(subject.daily_backup_extension?).to be true

      subject.content = invalid_content
      expect(subject.daily_backup_extension?).to be false
    end
  end

  describe 'perform_associated_job' do
    let(:invalid_content) do
      data = { test: 'hello world!' }
      "002#{Base64.encode64(JSON.dump(data))}"
    end

    let(:backup_email_archive_content) do
      data = { subtype: 'backup.email_archive' }
      "002#{Base64.encode64(JSON.dump(data))}"
    end

    let(:perform_later_content) do
      data = { frequency: 'daily', url: 'http://test.com' }
      "002#{Base64.encode64(JSON.dump(data))}"
    end

    specify do
      subject.content = invalid_content
      expect(subject.perform_associated_job).to be_nil

      subject.content = perform_later_content
      expect do
        subject.perform_associated_job
      end.to have_enqueued_job(ExtensionJob)
    end
  end
end
