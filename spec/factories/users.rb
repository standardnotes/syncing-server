FactoryBot.define do
  sequence(:email) { |n| "test.user.#{n}@sn-email.org" }

  factory :user do
    email

    initialize_with do
      user_manager = SyncEngine::V20190520::UserManager.new(User)
      params = ActionController::Parameters.new(pw_cost: 110_000, version: '003')

      result = user_manager.register(email, password, params)
      result[:user]
    end
  end
end
