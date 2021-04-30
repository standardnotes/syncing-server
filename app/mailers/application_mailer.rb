class ApplicationMailer < ActionMailer::Base
  default from: "Standard Notes <#{ENV['EMAIL_FROM_ADDRESS']}>"
  layout 'mailer'
end
