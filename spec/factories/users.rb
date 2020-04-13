FactoryBot.define do
  sequence(:email) { |n| "test.user.#{n}@sn-email.org" }

  factory :user do
    email
    version { '003' }

    initialize_with do
      user_manager = SyncEngine::V20200115::UserManager.new(User)

      api_version = '20200115' if version == '004'
      params = ActionController::Parameters.new(pw_cost: 110_000, api_version: api_version, version: version)

      user_agent = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/51.0.2704.103 Safari/537.36'
      result = user_manager.register(email, password, params, user_agent)

      result[:user]
    end
  end
end
