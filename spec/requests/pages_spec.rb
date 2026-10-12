require "rails_helper"

RSpec.describe "Pages", type: :request do
  describe "GET /privacy" do
    it "ログインしていなくても、プライバシーポリシーが見られる" do
      get privacy_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("プライバシーポリシー")
      expect(response.body).to include("LINE のユーザーID、表示名、プロフィール画像の URL")
      expect(response.body).to include(Rails.configuration.x.contact_form_url)
    end
  end

  describe "GET /terms" do
    it "ログインしていなくても、利用規約が見られる" do
      get terms_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("利用規約")
      expect(response.body).to include(%(href="#{privacy_path}"))
    end
  end
end
