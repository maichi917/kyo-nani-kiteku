require "rails_helper"

RSpec.describe DailyAdvice do
  let(:user) { User.create!(line_user_id: "U1234567890", name: "まい") }

  def build_advice(**attrs)
    user.daily_advices.build(date: Date.new(2026, 10, 11), outfit_level: :cardigan,
                             max_temp: 19.4, min_temp: 12.0, yesterday_max_temp: 21.0, precipitation_probability: 10, **attrs)
  end

  it "日付・服装・気温があれば保存できる" do
    expect(build_advice).to be_valid
  end

  it "同じ人の同じ日のアドバイスは、2件目を保存できない" do
    build_advice.save!

    expect(build_advice).not_to be_valid
  end

  it "別の日なら保存できる" do
    build_advice.save!

    expect(build_advice(date: Date.new(2026, 10, 12))).to be_valid
  end

  describe "一言" do
    it "AI の一言があれば、それを使う" do
      advice = build_advice(comment: "ホーム用の一言", line_comment: "LINE 用の一言")

      expect(advice.home_comment).to eq "ホーム用の一言"
      # LINE は、今日なにちゃんのあいさつをアプリが先頭に入れる
      expect(advice.line_message_comment).to eq "おはよう！\n今日なにちゃんだよ☀️\n\nLINE 用の一言"
    end

    it "AI の一言が空なら、服装ごとの説明文を使う（LINE はふつうのあいさつを付ける）" do
      advice = build_advice(comment: nil, line_comment: "")

      expect(advice.home_comment).to eq Outfit.description(:cardigan)
      expect(advice.line_message_comment).to eq "おはようございます☀️\n#{Outfit.description(:cardigan)}"
    end
  end

  describe "User#reset_today_advice!" do
    it "今日のアドバイスだけを消す" do
      travel_to Time.zone.local(2026, 10, 11, 12, 0) do
        build_advice(date: Date.new(2026, 10, 10)).save!
        build_advice(date: Date.new(2026, 10, 11)).save!

        user.reset_today_advice!

        expect(user.daily_advices.pluck(:date)).to eq [ Date.new(2026, 10, 10) ]
      end
    end

    it "今日のアドバイスがなくても、エラーにならない" do
      expect { user.reset_today_advice! }.not_to raise_error
    end
  end

  describe ".for_today" do
    before do
      user.update!(sensitivity: :cold)
      user.create_location!(name: "東京都渋谷区", latitude: 35.66, longitude: 139.69)
    end

    def stub_forecast
      stub_request(:get, Weather::Forecast::ENDPOINT).with(query: hash_including({})).to_return(
        status: 200,
        body: { daily: { time: [ "2026-10-11", "2026-10-12" ], temperature_2m_max: [ 21.0, 22.0 ],
                         temperature_2m_min: [ 15.0, 13.0 ], precipitation_probability_max: [ 0, 60 ] } }.to_json
      )
    end

    around { |example| travel_to(Time.zone.local(2026, 10, 12, 7, 0)) { example.run } }

    it "今日の分がなければ、天気・服装の判定・AI の一言をそろえて保存する" do
      stub_forecast
      stub_gemini(home: "ホーム用", line: "LINE 用")

      advice = described_class.for_today(user)

      expect(advice).to be_persisted
      expect(advice).to have_attributes(
        date: Date.new(2026, 10, 12), max_temp: 22.0, min_temp: 13.0, yesterday_max_temp: 21.0,
        precipitation_probability: 60, comment: "ホーム用", line_comment: "LINE 用"
      )
      # 22℃ でも寒がりなので、−3℃ の 19℃ で判定して「長袖＋カーディガン」
      expect(advice.outfit_level).to eq "cardigan"
    end

    it "今日の分があれば、天気も AI も呼ばずに使い回す" do
      stub_forecast
      stub_gemini
      first = described_class.for_today(user)

      expect(described_class.for_today(user)).to eq first
      expect(a_request(:get, Weather::Forecast::ENDPOINT).with(query: hash_including({}))).to have_been_made.once
      expect(a_request(:post, Gemini::AdviceWriter::ENDPOINT)).to have_been_made.once
    end

    it "AI に失敗しても、一言は空のまま保存して、説明文で代わりにする" do
      stub_forecast
      stub_request(:post, Gemini::AdviceWriter::ENDPOINT).to_return(status: 503)

      advice = described_class.for_today(user)

      expect(advice).to be_persisted
      expect(advice.comment).to be_nil
      expect(advice.home_comment).to eq Outfit.description(:cardigan)
    end

    it "天気が取れなければ Weather::Error を投げて、何も保存しない" do
      stub_request(:get, Weather::Forecast::ENDPOINT).with(query: hash_including({})).to_return(status: 500)

      expect { described_class.for_today(user) }.to raise_error(Weather::Error)
      expect(user.daily_advices).to be_empty
    end
  end
end
