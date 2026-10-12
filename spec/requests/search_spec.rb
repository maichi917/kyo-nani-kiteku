require "rails_helper"

RSpec.describe "Search", type: :request do
  let(:user) { User.create!(line_user_id: "U1234567890", name: "まい") }

  # LINE ログインの流れを、LINE の API を偽物にして通す
  def sign_in(user)
    stub_request(:post, Line::Login::TOKEN_URL).to_return(status: 200, body: { id_token: "dummy" }.to_json)
    stub_request(:post, Line::Login::VERIFY_URL).to_return(status: 200, body: { sub: user.line_user_id, name: user.name }.to_json)
    get line_login_path
    state = Rack::Utils.parse_query(URI(response.location).query).fetch("state")
    get line_callback_path(code: "abc", state:)
  end

  before do
    stub_request(:get, Weather::Forecast::ENDPOINT).with(query: hash_including({})).to_return(
      status: 200,
      body: { daily: { time: [ "2026-10-11", "2026-10-12" ], temperature_2m_max: [ 23.5, 24.6 ],
                       temperature_2m_min: [ 15.4, 15.2 ], precipitation_probability_max: [ 4, 0 ] } }.to_json
    )
  end

  describe "トップ（/）" do
    it "ログインしていなければ、トップを出す（タブはない）" do
      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('class="tab-bar"')
    end

    it "ログイン中でマイエリアがあれば、ホームへ" do
      user.create_location!(name: "東京都渋谷区", latitude: 35.66, longitude: 139.69)
      sign_in(user)

      get root_path

      expect(response).to redirect_to(home_path)
    end

    it "ログイン中でマイエリアがなければ、設定画面へ" do
      sign_in(user)

      get root_path

      expect(response).to redirect_to(settings_path)
    end
  end

  describe "さがす（/search）" do
    it "ログイン中でも、ほかの場所の天気を出す。タブはさがすが今いる画面" do
      user.create_location!(name: "東京都渋谷区", latitude: 35.66, longitude: 139.69)
      sign_in(user)

      get search_path(name: "東京都中央区", lat: "35.6706", lon: "139.772")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(<h2 class="weather-place">東京都中央区</h2>))
      expect(response.body).to include('class="tab is-current" aria-current="page" href="/search"')
    end

    it "ログインしていなくても使える（トップと同じ内容で、タブはない）" do
      get search_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(<h2 class="weather-place">東京都渋谷区</h2>))
      expect(response.body).not_to include('class="tab-bar"')
    end
  end
end
