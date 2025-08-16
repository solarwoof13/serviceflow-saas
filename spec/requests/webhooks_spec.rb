require 'rails_helper'

RSpec.describe "Webhooks", type: :request do
  describe "GET /jobber" do
    it "returns http success" do
      get "/webhooks/jobber"
      expect(response).to have_http_status(:success)
    end
  end

end
