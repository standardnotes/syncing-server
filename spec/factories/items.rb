FactoryBot.define do
  factory :item do
    trait :extension_type do
      content_type { 'SF|Extension' }
    end

    trait :note_type do
      content_type { 'Note' }
    end

    trait :mfa_type do
      content { "---#{Base64.encode64(JSON.dump(secret: 'base32secretkey3232'))}" }
      content_type { 'SF|MFA' }
    end
  end
end