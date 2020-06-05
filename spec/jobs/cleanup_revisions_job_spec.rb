require 'rails_helper'

RSpec.describe CleanupRevisionsJob do
  subject do
    described_class.new
  end

  let(:test_user) do
    create(:user, password: '123456')
  end

  let(:test_item) do
    create(:item, :note_type, user_uuid: test_user.uuid, content: 'This is a test note.')
  end

  before(:each) do
    amount_of_days = 35
    amount_of_revisions_per_day = 40

    amount_of_days.times do |days_from_today|
      revisions = []

      amount_of_revisions_per_day.times do |n|
        revisions.push(
          create(
            :revision,
            uuid: "#{days_from_today}-#{n}",
            content: (0...8).map { (65 + rand(26)).chr }.join,
            created_at: days_from_today.days.ago
          )
        )
      end

      revisions.each do |revision|
        create(:item_revision, item_uuid: test_item.uuid, revision_uuid: revision.uuid)
      end
    end
  end

  it 'should clean up revisions from last 30 days' do
    subject.perform(test_item.uuid, 30)

    revisions = test_item.revisions.where(created_at: 30.days.ago..DateTime::Infinity.new)
    expect(revisions.length).to eq(466)
  end

  it 'should clean up revisions in a decaying fashion for last 30 days' do
    subject.perform(test_item.uuid, 30)

    revisions = test_item.revisions.where(created_at: 30.days.ago..DateTime::Infinity.new)

    revisions_by_date = {}
    revisions.each do |revision|
      unless revisions_by_date[revision['created_at'].to_date]
        revisions_by_date[revision['created_at'].to_date] = []
      end
      revisions_by_date[revision['created_at'].to_date].push(revision)
    end

    expected_revision_counts = []
    (1..30).reverse_each do |n|
      if n < 2
        n = 2
      end
      expected_revision_counts.push(n)
    end

    index = 0
    revisions_by_date.each do |_date, revisions_in_date|
      expect(revisions_in_date.length).to eq(expected_revision_counts[index])
      index += 1
    end
  end
end
