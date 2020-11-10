require 'rails_helper'

RSpec.describe SaveRevisionJob do
  subject do
    described_class.new
  end

  let(:test_user) do
    create(:user, password: '123456')
  end

  let(:test_item) do
    create(:item, :note_type, user_uuid: test_user.uuid, content: 'This is a test note.')
  end

  it 'should save a revision for item' do
    subject.perform(test_item.uuid)

    item_revisions = ItemRevision.where(item_uuid: test_item.uuid)

    expect(item_revisions.length).to eq(1)

    revision = Revision.find(item_revisions.first.revision_uuid)

    expect(revision.content).to eq('This is a test note.')
  end
end
