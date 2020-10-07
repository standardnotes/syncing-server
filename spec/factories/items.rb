def encode_content(content)
  "002#{Base64.encode64(JSON.dump(content))}"
end

FactoryBot.define do
  factory :item do
    trait :extension_type do
      content_type { 'SF|Extension' }
    end

    trait :note_type do
      content_type { 'Note' }
      created_at { DateTime.now }
      updated_at { DateTime.now }
    end

    trait :mfa_type do
      content { encode_content(secret: 'base32secretkey3232') }
      content_type { 'SF|MFA' }
    end

    trait :backup_daily do
      content { encode_content(frequency: 'daily', url: 'http://test.com') }
      content_type { 'SF|Extension' }
    end

    trait :backup_realtime do
      content { encode_content(frequency: 'realtime', url: 'http://test.com') }
      content_type { 'SF|Extension' }
    end

    trait :with_items_key_id do
      items_key_id { SecureRandom.uuid }
    end

    trait :with_auth_hash do
      auth_hash { '003:something' }
    end
  end
end
