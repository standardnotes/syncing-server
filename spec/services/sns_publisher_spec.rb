require 'rails_helper'
require 'aws-sdk-sns'

RSpec.describe SnsPublisher do
  let(:stub_client) do
    Aws::SNS::Client.new(stub_responses: true)
  end

  subject do
    described_class.new
  end

  describe '#publish_mail_backup_attachment_too_big' do
    before do
      allow(ENV).to receive(:fetch)
      allow(ENV).to receive(:[])
      expect(Aws::SNS::Client).to receive(:new).and_return(stub_client)
    end

    context 'sns topic not configured' do
      before do
        allow(ENV).to receive(:fetch).with('SNS_TOPIC_ARN', nil).and_return(nil)
      end
      it 'should not publish events' do
        expect(stub_client).not_to receive(:publish)

        subject.publish_mail_backup_attachment_too_big('test@test.com', '1-2-3', 10.megabyte, 1.megabyte)
      end
    end
    context 'sns topic configured' do
      before do
        allow(ENV).to receive(:fetch).with('SNS_TOPIC_ARN', nil).and_return('test-arn')
      end
      it 'should publish events' do
        expect(stub_client).to receive(:publish)

        subject.publish_mail_backup_attachment_too_big('test@test.com', '1-2-3', 10.megabyte, 1.megabyte)
      end
    end
  end
end
