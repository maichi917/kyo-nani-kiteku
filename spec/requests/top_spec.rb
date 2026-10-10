require "rails_helper"

RSpec.describe "Top", type: :request do
  # Open-Meteo を偽物の返事に差し替える。指定しなければ「昨日の最高23.5℃、今日は最高24.6℃・最低15.2℃・降水確率0%」
  def stub_forecast(max: 24.6, min: 15.2, precipitation: 0, yesterday_max: 23.5)
    stub_request(:get, Weather::Forecast::ENDPOINT).with(query: hash_including({})).to_return(
      status: 200,
      body: { daily: { time: [ "2026-10-09", "2026-10-10" ],
                       temperature_2m_max: [ yesterday_max, max ],
                       temperature_2m_min: [ 14.0, min ],
                       precipitation_probability_max: [ 0, precipitation ] } }.to_json
    )
  end

  describe "GET /" do
    it "初期表示は渋谷区の天気と服装" do
      stub_forecast

      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("東京都渋谷区の今日")
      expect(response.body).to include("25℃")
      # 24.6℃ は四捨五入して 25℃。画面の表示に合わせて半袖になる
      expect(response.body).to include("半袖")
      expect(response.body).to include("昨日より <strong>1℃</strong> 高い")
    end

    it "候補から選んだ場所（name・lat・lon）の天気を出す" do
      stub_forecast

      get root_path(name: "東京都中央区", lat: "35.6706", lon: "139.772")

      expect(response.body).to include("東京都中央区の今日")
      expect(a_request(:get, Weather::Forecast::ENDPOINT).with(query: hash_including(latitude: "35.6706", longitude: "139.772")))
        .to have_been_made
    end

    it "lat・lon が足りなければ渋谷区を出す" do
      stub_forecast

      get root_path(name: "東京都中央区")

      expect(response.body).to include("東京都渋谷区の今日")
    end

    it "降水確率が50%以上なら傘の帯を出す" do
      stub_forecast(precipitation: 60)

      get root_path

      expect(response.body).to include("雨の可能性あり。傘を持っていこう")
    end

    it "降水確率が50%未満なら傘の帯の代わりに、雨は降らなさそうと出す" do
      stub_forecast(precipitation: 40)

      get root_path

      expect(response.body).not_to include("傘を持っていこう")
      expect(response.body).to include("今日は雨は降らなさそうです！")
    end

    it "暑さと寒暖差のバッジを出す" do
      stub_forecast(max: 35.2, min: 26.0)

      get root_path

      expect(response.body).to include("猛暑日")
      expect(response.body).to include("寒暖差あり")
    end

    it "Open-Meteo が失敗したら、エラー画面にせずメッセージを出す" do
      stub_request(:get, Weather::Forecast::ENDPOINT).with(query: hash_including({})).to_return(status: 500)

      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("天気を取得できませんでした")
    end
  end
end
