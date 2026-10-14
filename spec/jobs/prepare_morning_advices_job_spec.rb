require "rails_helper"

RSpec.describe PrepareMorningAdvicesJob do
  # やり直しの予約まで、テストの中で順番に動かす（perform_enqueued_jobs）
  include ActiveJob::TestHelper

  def create_user(line_user_id, name, latitude: 35.66, area: true)
    user = User.create!(line_user_id:, name:)
    user.create_location!(name: "東京都渋谷区", latitude:, longitude: 139.69) if area
    user
  end

  def forecast_body
    { daily: { time: [ "2026-10-10", "2026-10-11" ], temperature_2m_max: [ 21.0, 22.0 ],
               temperature_2m_min: [ 15.0, 16.0 ], precipitation_probability_max: [ 0, 10 ] } }.to_json
  end

  def gemini_body
    { candidates: [ { content: { parts: [ { text: { home: "ホーム用", line: "LINE 用" }.to_json } ] } } ] }.to_json
  end

  before do
    stub_request(:get, Weather::Forecast::ENDPOINT).with(query: hash_including({})).to_return(status: 200, body: forecast_body)
  end

  it "マイエリアを設定している全員の、今日のアドバイスとひとことを準備する（LINE は送らない）" do
    stub_gemini
    a = create_user("U_A", "Aさん")
    b = create_user("U_B", "Bさん")

    described_class.perform_now

    [ a, b ].each { |user| expect(user.daily_advices.sole.line_comment).to be_present }
    expect(a_request(:post, Line::Messaging::PUSH_URL)).not_to have_been_made
  end

  it "マイエリアを設定していない人の分は準備しない" do
    user = create_user("U_NO_AREA", "未設定さん", area: false)

    described_class.perform_now

    expect(user.daily_advices).to be_empty
  end

  it "天気が取れない人がいても、ほかの人の分は準備して、ジョブのやり直しを予約する" do
    stub_gemini
    create_user("U_FAIL", "失敗さん", latitude: 35.0)
    ok = create_user("U_OK", "OKさん")
    stub_request(:get, Weather::Forecast::ENDPOINT).with(query: hash_including(latitude: "35.0")).to_return(status: 503)

    expect { described_class.perform_now }.to have_enqueued_job(described_class)
    expect(ok.daily_advices.sole.line_comment).to be_present
  end

  it "天気は保存してあるのにひとことがない人は、やり直しで書き足す（天気は取りに行かない）" do
    user = create_user("U_A", "Aさん")
    # 天気は保存してあるが、そのとき Gemini に失敗して、ひとことがないアドバイス
    user.daily_advices.create!(date: Date.current, outfit_level: :long_sleeve,
                               max_temp: 22.0, min_temp: 16.0, yesterday_max_temp: 21.0, precipitation_probability: 10)
    # 6:32 は混んでいて失敗、やり直しで成功
    stub_request(:post, Gemini::AdviceWriter::ENDPOINT).to_return({ status: 503 }, { status: 200, body: gemini_body })

    perform_enqueued_jobs { described_class.perform_later }

    expect(user.daily_advices.sole.line_comment).to eq "LINE 用"
    expect(a_request(:get, Weather::Forecast::ENDPOINT).with(query: hash_including({}))).not_to have_been_made
  end

  it "5回やっても準備できなければ、あきらめる（エラーにはしない）" do
    user = create_user("U_A", "Aさん")
    stub_request(:post, Gemini::AdviceWriter::ENDPOINT).to_return(status: 503)

    expect { perform_enqueued_jobs { described_class.perform_later } }.not_to raise_error

    expect(user.daily_advices.sole.line_comment).to be_nil
  end

  it "毎朝6:32（日本時間）に予約されている" do
    task = YAML.load_file(Rails.root.join("config/recurring.yml")).dig("production", "prepare_morning_advices")

    expect(task).to eq("class" => "PrepareMorningAdvicesJob", "schedule" => "32 6 * * * Asia/Tokyo")
  end
end
