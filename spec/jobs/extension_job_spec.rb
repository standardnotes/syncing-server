require 'rails_helper'

RSpec.describe ExtensionJob do
  subject do
    described_class.new
  end

  let(:test_user) do
    create(:user, password: '123456')
  end

  let(:test_items) do
    create_list(
      :item,
      2,
      :note_type,
      user_uuid: test_user.uuid,
      content: (0...8).map { (65 + rand(26)).chr }.join
    )
  end

  it 'should send payload with items to extensions server' do
    response = Net::HTTPSuccess.new(1.0, '200', 'OK')
    expect_any_instance_of(Net::HTTP).to receive(:request).with(an_instance_of(Net::HTTP::Post)) { response }

    subject.perform(
      test_user.uuid,
      'https://extensions-server-dummy.standardnotes.org',
      '123',
      test_items.map(&:uuid)
    )
  end

  it 'should not send payload with items to extensions server if an error occures' do
    expect_any_instance_of(Net::HTTP).not_to receive(:request)

    subject.perform(
      test_user.uuid,
      'https://extensions-server-dummy.standardnotes.org',
      '123',
      [nil]
    )
  end

end
