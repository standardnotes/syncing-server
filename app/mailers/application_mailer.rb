class ApplicationMailer < ActionMailer::Base
  default from: 'Standard Notes <help@standardnotes.org>'
  layout 'mailer'
end
