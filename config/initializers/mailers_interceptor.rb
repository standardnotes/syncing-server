unless Rails.configuration.smime[:certfilename].empty?
  ActionMailer::Base.register_interceptor(SmimeInterceptor)
end