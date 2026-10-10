require "rails_helper"

RSpec.describe MorningNotificationJob do
  def create_user(line_user_id, name, area: true)
    user = User.create!(line_user_id:, name:)
    user.create_location!(name: "東京都渋谷区", latitude: 35.66, longitude: 139.69) if area
    user
  end

  before do
    allow(Line::Messaging).to receive(:channel_access_token).and_return("TEST_TOKEN")
    stub_request(:get, Weather::Forecast::ENDPOINT).with(query: hash_including({})).to_return(
      status: 200,
      body: { daily: { time: [ "2026-10-10", "2026-10-11" ], temperature_2m_max: [ 21.0, 22.0 ],
                       temperature_2m_min: [ 15.0, 16.0 ], precipitation_probability_max: [ 0, 10 ] } }.to_json
    )
  end

  it "マイエリアを設定している全員に送る" do
    stub_request(:post, Line::Messaging::PUSH_URL).to_return(status: 200, body: "{}")
    create_user("U_A", "Aさん")
    create_user("U_B", "Bさん")

    described_class.perform_now

    expect(a_request(:post, Line::Messaging::PUSH_URL).with(body: hash_including(to: "U_A"))).to have_been_made.once
    expect(a_request(:post, Line::Messaging::PUSH_URL).with(body: hash_including(to: "U_B"))).to have_been_made.once
  end

  it "マイエリアを設定していない人には送らない" do
    stub_request(:post, Line::Messaging::PUSH_URL).to_return(status: 200, body: "{}")
    create_user("U_NO_AREA", "未設定さん", area: false)

    described_class.perform_now

    expect(a_request(:post, Line::Messaging::PUSH_URL)).not_to have_been_made
  end

  it "1人に送れなくても、ほかの人には送る" do
    create_user("U_BLOCKED", "ブロックさん")
    create_user("U_OK", "OKさん")
    stub_request(:post, Line::Messaging::PUSH_URL).with(body: hash_including(to: "U_BLOCKED")).to_return(status: 400, body: "{}")
    stub_request(:post, Line::Messaging::PUSH_URL).with(body: hash_including(to: "U_OK")).to_return(status: 200, body: "{}")

    expect { described_class.perform_now }.not_to raise_error

    expect(a_request(:post, Line::Messaging::PUSH_URL).with(body: hash_including(to: "U_OK"))).to have_been_made.once
  end

  it "毎朝7時（日本時間）に予約されている" do
    task = YAML.load_file(Rails.root.join("config/recurring.yml")).dig("production", "morning_notification")

    expect(task).to eq("class" => "MorningNotificationJob", "schedule" => "0 7 * * * Asia/Tokyo")
  end
end
