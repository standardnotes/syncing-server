require 'rails_helper'

RSpec.describe SnsPublisher do
  subject do
    described_class.new
  end

  describe '#publish_mail_backup_attachment_too_big' do
    context 'sns topic not configured' do
      before do
        allow(ENV).to receive(:fetch)
        allow(ENV).to receive(:fetch).with('SNS_TOPIC_ARN', nil).and_return(nil)
      end
      it 'should not publish events' do
        expect_any_instance_of(Aws::SNS::Client).not_to receive(:publish)

        subject.publish_mail_backup_attachment_too_big('test@test.com', 1.megabyte)
      end
    end
    context 'sns topic configured' do
      before do
        allow(ENV).to receive(:fetch)
        allow(ENV).to receive(:fetch).with('SNS_TOPIC_ARN', nil).and_return('test-arn')
      end
      it 'should publish events' do
        expect_any_instance_of(Aws::SNS::Client).to receive(:publish)

        subject.publish_mail_backup_attachment_too_big('test@test.com', 1.megabyte)
      end
    end
  end
end
