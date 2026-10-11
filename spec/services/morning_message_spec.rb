require "rails_helper"

RSpec.describe MorningMessage do
  let(:user) { User.create!(line_user_id: "U1234567890", name: "まい") }

  # 保存済みの「今日のアドバイス」から文面を作る（天気の API も AI も呼ばない）
  def build(max: 24.6, min: 18.0, precipitation: 0, yesterday_max: 23.5, line_comment: "おはよう！今日なにちゃんだよ☀️\n羽織りものを持っていってね🧥")
    advice = user.daily_advices.build(date: Date.new(2026, 10, 11), outfit_level: :long_sleeve, max_temp: max, min_temp: min,
                                      yesterday_max_temp: yesterday_max, precipitation_probability: precipitation, line_comment:)
    described_class.new(place_name: "東京都渋谷区", advice:).text
  end

  it "今日なにちゃんの一言から始まり、場所・気温・昨日との差・降水確率・おすすめ・アプリの URL が入る" do
    text = build

    expect(text).to start_with("おはよう！今日なにちゃんだよ☀️\n羽織りものを持っていってね🧥")
    expect(text).to include("📍 東京都渋谷区")
    expect(text).to include("🌡 最高25℃ ／ 最低18℃（昨日より1℃高い）")
    expect(text).to include("☔️ 降水確率 0%")
    expect(text).to include("👕 おすすめ：長袖1枚")
    expect(text).to include(Rails.configuration.x.app_url)
  end

  it "AI の一言がない日は、ふつうのあいさつと服装ごとの説明文から始まる" do
    expect(build(line_comment: nil)).to start_with("おはようございます☀️\n#{Outfit.description(:long_sleeve)}")
  end

  it "昨日と同じ気温なら「昨日と同じくらい」" do
    expect(build(max: 24.0, yesterday_max: 23.6)).to include("（昨日と同じくらい）")
  end

  it "雨の日は傘、そうでない日は晴れのお知らせ" do
    expect(build(precipitation: 60)).to include("🌂 雨の可能性あり！傘を持っていこう")
    expect(build(precipitation: 10)).to include("☀️ 今日は雨は降らなさそうです！")
  end

  it "暑さの段階と寒暖差があれば、お知らせに入る" do
    text = build(max: 35.2, min: 26.0)

    expect(text).to include("🥵 猛暑日。熱中症に気をつけて")
    expect(text).to include("🧥 寒暖差あり。羽織るものがあると安心")
  end

  describe ".for" do
    it "今日のアドバイスを作って（天気・体感タイプ・AI の一言）、文面にする" do
      user.update!(sensitivity: :cold)
      user.create_location!(name: "東京都渋谷区", latitude: 35.66, longitude: 139.69)
      stub_request(:get, Weather::Forecast::ENDPOINT).with(query: hash_including(latitude: "35.66", longitude: "139.69")).to_return(
        status: 200,
        body: { daily: { time: [ "2026-10-10", "2026-10-11" ], temperature_2m_max: [ 21.0, 22.0 ],
                         temperature_2m_min: [ 15.0, 16.0 ], precipitation_probability_max: [ 0, 10 ] } }.to_json
      )
      stub_gemini(line: "おはよう！今日なにちゃんだよ☀️\nカーディガンがちょうどいいよ🧥")

      text = described_class.for(user)

      expect(text).to start_with("おはよう！今日なにちゃんだよ☀️\nカーディガンがちょうどいいよ🧥")
      # 22℃ でも寒がりなので、−3℃ の 19℃ で判定して「長袖＋カーディガン」
      expect(text).to include("👕 おすすめ：長袖＋カーディガン")
    end
  end
end
