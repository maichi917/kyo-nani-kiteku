require "rails_helper"

RSpec.describe MorningMessage do
  # 天気の API を呼ばずに、決まった材料で文面を作る
  def build(max: 24.6, min: 18.0, precipitation: 0, yesterday_max: 23.5, heat_level: nil, umbrella: false, temperature_gap: false)
    forecast = Weather::Forecast::Result.new(date: Date.new(2026, 10, 11), max_temp: max, min_temp: min,
                                             precipitation_probability: precipitation, yesterday_max_temp: yesterday_max)
    judgment = Outfit::Judge::Result.new(outfit: :long_sleeve, umbrella:, heat_level:, temperature_gap:)
    described_class.new(place_name: "東京都渋谷区", forecast:, judgment:, comment: "長袖1枚でちょうどいい気温です").text
  end

  it "場所・気温・昨日との差・降水確率・おすすめ・一言・アプリの URL が入る" do
    text = build

    expect(text).to include("📍 東京都渋谷区")
    expect(text).to include("🌡 最高25℃ ／ 最低18℃（昨日より1℃高い）")
    expect(text).to include("☔️ 降水確率 0%")
    expect(text).to include("👕 おすすめ：長袖1枚\n長袖1枚でちょうどいい気温です")
    expect(text).to include(Rails.configuration.x.app_url)
  end

  it "昨日と同じ気温なら「昨日と同じくらい」" do
    expect(build(max: 24.0, yesterday_max: 23.6)).to include("（昨日と同じくらい）")
  end

  it "雨の日は傘、そうでない日は晴れのお知らせ" do
    expect(build(umbrella: true)).to include("🌂 雨の可能性あり！傘を持っていこう")
    expect(build(umbrella: false)).to include("☀️ 今日は雨は降らなさそうです！")
  end

  it "暑さの段階と寒暖差があれば、お知らせに入る" do
    text = build(heat_level: :very_hot_day, temperature_gap: true)

    expect(text).to include("🥵 猛暑日。熱中症に気をつけて")
    expect(text).to include("🧥 寒暖差あり。羽織るものがあると安心")
  end

  describe ".for" do
    it "ユーザーのマイエリアの天気と体感タイプで文面を作る" do
      user = User.create!(line_user_id: "U1234567890", name: "まい", sensitivity: :cold)
      user.create_location!(name: "東京都渋谷区", latitude: 35.66, longitude: 139.69)
      stub_request(:get, Weather::Forecast::ENDPOINT).with(query: hash_including(latitude: "35.66", longitude: "139.69")).to_return(
        status: 200,
        body: { daily: { time: [ "2026-10-10", "2026-10-11" ], temperature_2m_max: [ 21.0, 22.0 ],
                         temperature_2m_min: [ 15.0, 16.0 ], precipitation_probability_max: [ 0, 10 ] } }.to_json
      )

      # 22℃ でも寒がりなので、−3℃ の 19℃ で判定して「長袖＋カーディガン」
      expect(described_class.for(user)).to include("👕 おすすめ：長袖＋カーディガン")
    end
  end
end
