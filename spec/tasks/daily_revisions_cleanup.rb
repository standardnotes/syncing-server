require 'rails_helper'

Rails.application.load_tasks

RSpec.describe 'items:daily_revisions_cleanup' do
  let(:test_user) do
    create(:user, password: '123456')
  end

  let(:test_item) do
    create(:item, :note_type, user_uuid: test_user.uuid, content: 'This is a test note.', created_at: 60.days.ago)
  end

  describe 'stale excessive revisions' do
    before(:each) do
      amount_of_revisions = 10

      [35, 20].each do |number_of_days|
        revisions = create_list(
          :revision,
          amount_of_revisions,
          content: (0...8).map { (65 + rand(26)).chr }.join,
          created_at: number_of_days.days.ago,
          creation_date: number_of_days.days.ago
        )

        revisions.each do |revision|
          create(:item_revision, item_uuid: test_item.uuid, revision_uuid: revision.uuid)
        end
      end
    end

    it 'should clean up revisions excessive revisions' do
      run_task(task_name: 'items:daily_revisions_cleanup')

      revisions = test_item.revisions
      expect(revisions.length).to eq(12)
      expect(test_item.item_revisions.length).to eq(12)
    end

    it 'should clean up revisions in a decaying fashion' do
      run_task(task_name: 'items:daily_revisions_cleanup')

      revisions = test_item.revisions

      revisions_by_date = {}
      revisions.each do |revision|
        unless revisions_by_date[revision['creation_date']]
          revisions_by_date[revision['creation_date']] = []
        end
        revisions_by_date[revision['creation_date']].push(revision)
      end

      expected_revision_counts = {
        20.days.ago.strftime('%Y-%m-%d') => 10,
        35.days.ago.strftime('%Y-%m-%d') => 2,
      }

      index = 0
      revisions_by_date.each do |date, revisions_in_date|
        expect(expected_revision_counts[date.to_s]).to eq(revisions_in_date.length)
        index += 1
      end
    end
  end
end

def run_task(task_name:)
  stdout = StringIO.new
  $stdout = stdout
  Rake::Task[task_name].invoke
  $stdout = STDOUT
  Rake.application[task_name].reenable

  stdout.string
end
