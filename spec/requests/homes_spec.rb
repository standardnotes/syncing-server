require 'rails_helper'

RSpec.describe 'Index', type: :request do
  describe 'GET /' do
    it 'shows user message' do
      get '/'
      expect(response).to have_http_status(200)
      expect(response.body).to include("Hi! You're not supposed to be here.")
    end
  end
end
