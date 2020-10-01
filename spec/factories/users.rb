FactoryBot.define do
  sequence(:email) { |n| "test.user.#{n}@sn-email.org" }

  factory :user do
    email
    version { '003' }

    initialize_with do
      api_version = case version
      when '004'
        user_manager = SyncEngine::V20200115::UserManager.new(User)
        '20200115'
      when '003'
        user_manager = SyncEngine::V20190520::UserManager.new(User)
        '20190520'
      else
        user_manager = SyncEngine::V20161215::UserManager.new(User)
        '20161215'
      end
      params = ActionController::Parameters.new(
        api: api_version,
        version: version,
        origination: 'registration',
        created: DateTime.now.to_i.to_s
      )
      result = user_manager.register(email, password, params)

      result[:user]
    end

    trait :legacy_001 do
      version { '001' }
      pw_salt { 'salt' }
      pw_cost { 1 }
      pw_alg { 'alg' }
      pw_func { 'func' }
      pw_key_size { 1 }
    end
  end
end
