require "rails_helper"

RSpec.describe "Top", type: :request do
  describe "GET /" do
    it "トップページが表示される" do
      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("今日なに着てく？")
    end
  end
end
