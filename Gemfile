source 'https://rubygems.org'

gem 'rails', '5.1.7'
gem 'mysql2', '>= 0.3.13', '< 0.5'
gem 'whenever', :require => false
gem 'shoryuken'
gem 'secure_headers'
gem 'jwt'
gem 'bcrypt'
gem 'aws-sdk-sqs'
gem 'rack-cors', :require => 'rack/cors'
gem 'haml-rails'
gem 'dotenv-rails'
gem "sentry-raven"
gem 'rotp'

# Used for 'respond_to' feature
gem 'responders', '~> 2.0'

group :development, :test, :docker_development do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug'
  gem 'spring'
  gem 'puma'
  gem 'listen'
  gem 'rspec-rails'
end

group :development, :test do
  # Deployment tools
  gem 'capistrano'
  gem 'capistrano-bundler'
  gem 'capistrano-passenger', '>= 0.2.0'
  gem 'capistrano-rails'
  gem 'capistrano-rvm'
  gem 'capistrano-sidekiq'
  gem 'capistrano-shoryuken', github: 'mobitar/capistrano-shoryuken'
end

group :test do
  gem 'simplecov', require: false
  gem 'factory_bot_rails'
end
