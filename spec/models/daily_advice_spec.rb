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
      expect(advice.line_message_comment).to eq "LINE 用の一言"
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
end
