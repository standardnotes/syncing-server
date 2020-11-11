require 'rails_helper'

RSpec.describe AccountCleanupJob do
  subject do
    described_class.new
  end

  let(:test_user) do
    create(:user, password: '123456')
  end

  let(:original_item) do
    create(:item, :note_type, user_uuid: test_user.uuid, content: 'This is a test note.')
  end

  let(:amount_of_revisions_to_generate) do
    40
  end

  before(:each) do
    amount_of_revisions_to_generate.times do
      revision = Revision.new
      revision.auth_hash = original_item.auth_hash
      revision.content = (0...8).map { (65 + rand(26)).chr }.join
      revision.content_type = original_item.content_type
      revision.creation_date = Date.today
      revision.enc_item_key = original_item.enc_item_key
      revision.item_uuid = original_item.uuid
      revision.items_key_id = original_item.items_key_id
      revision.save

      item_revision = ItemRevision.new
      item_revision.item_uuid = original_item.uuid
      item_revision.revision_uuid = revision.uuid
      item_revision.save
    end
  end

  it 'should remove all items and their revisions for an account' do
    subject.perform(test_user.uuid)

    items = Item.all

    expect(items.length).to eq(0)

    revisions = Revision.all

    expect(revisions.length).to eq(0)

    item_revisions = ItemRevision.all

    expect(item_revisions.length).to eq(0)
  end
end
