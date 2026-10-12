require "rails_helper"

RSpec.describe "Home", type: :request do
  let(:user) { User.create!(line_user_id: "U1234567890", name: "まい") }

  # LINE ログインの流れを、LINE の API を偽物にして通す
  def sign_in(user)
    stub_request(:post, Line::Login::TOKEN_URL).to_return(status: 200, body: { id_token: "dummy" }.to_json)
    stub_request(:post, Line::Login::VERIFY_URL).to_return(status: 200, body: { sub: user.line_user_id, name: user.name }.to_json)
    get line_login_path
    state = Rack::Utils.parse_query(URI(response.location).query).fetch("state")
    get line_callback_path(code: "abc", state:)
  end

  def stub_forecast(status: 200)
    stub_request(:get, Weather::Forecast::ENDPOINT).with(query: hash_including({})).to_return(
      status:,
      body: { daily: { time: [ "2026-10-11", "2026-10-12" ], temperature_2m_max: [ 21.0, 22.0 ],
                       temperature_2m_min: [ 15.0, 13.0 ], precipitation_probability_max: [ 0, 60 ] } }.to_json
    )
  end

  around { |example| travel_to(Time.zone.local(2026, 10, 12, 8, 0)) { example.run } }

  describe "ログインしていないとき" do
    it "トップへ戻る" do
      get home_path

      expect(response).to redirect_to(root_path)
    end
  end

  describe "マイエリアがないとき" do
    it "設定画面へ案内する" do
      sign_in(user)

      get home_path

      expect(response).to redirect_to(settings_path)
      expect(flash[:notice]).to eq "まずはマイエリアを設定してください"
    end
  end

  describe "マイエリアがあるとき" do
    before do
      user.create_location!(name: "東京都渋谷区", latitude: 35.66, longitude: 139.69)
      sign_in(user)
    end

    it "マイエリアの今日の天気と、AI の一言を出す" do
      stub_forecast
      stub_gemini(home: "朝晩は冷えるので、羽織りものがあると安心です。")

      get home_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("🏠 東京都渋谷区")
      expect(response.body).to include("朝晩は冷えるので、羽織りものがあると安心です。")
      expect(response.body).to include("雨の可能性あり。傘を持っていこう")
      expect(response.body).to include("毎朝 7:00 に今日の天気とおすすめの服装を LINE でお届け中！")
    end

    it "今日のアドバイスがあれば、それを使う（天気も AI も呼ばない）" do
      user.daily_advices.create!(date: Date.new(2026, 10, 12), outfit_level: :coat, max_temp: 10.0, min_temp: 5.0,
                                 yesterday_max_temp: 12.0, precipitation_probability: 0, comment: "保存してある一言")

      get home_path

      expect(response.body).to include("保存してある一言")
      expect(a_request(:get, Weather::Forecast::ENDPOINT).with(query: hash_including({}))).not_to have_been_made
    end

    it "AI に失敗した日は、服装ごとの説明文を出す" do
      stub_forecast
      stub_request(:post, Gemini::AdviceWriter::ENDPOINT).to_return(status: 503)

      get home_path

      # 22℃ でも、体感タイプがふつうなら「長袖1枚」
      expect(response.body).to include(Outfit.description(:long_sleeve))
    end

    it "天気が取れないときは、エラー画面にせずメッセージを出す" do
      stub_forecast(status: 500)

      get home_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("天気を取得できませんでした")
    end

    it "下のタブで、ホームが今いる画面になっている" do
      stub_forecast
      stub_gemini

      get home_path

      expect(response.body).to include('class="tab is-current" aria-current="page" href="/home"')
    end
  end
end
