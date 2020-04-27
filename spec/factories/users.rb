FactoryBot.define do
  sequence(:email) { |n| "test.user.#{n}@sn-email.org" }

  factory :user do
    email
    version { '003' }

    initialize_with do
      user_manager = SyncEngine::V20200115::UserManager.new(User)

      case version
      when '004'
        api_version = '20200115'
      else
        api_version = '20190520'
      end

      params = ActionController::Parameters.new(pw_cost: 110_000, api: api_version, version: version)

      user_agent = 'Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:47.0) Gecko/20100101 Firefox/47.0'
      result = user_manager.register(email, password, params, user_agent)

      result[:user]
    end
  end
end
