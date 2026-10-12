# テストでは、本物の API キーやトークンを使わない（失敗したときの表示に、本物の値が出ないようにする）
RSpec.configure do |config|
  config.before do
    allow(Gemini::AdviceWriter).to receive(:api_key).and_return("TEST_GEMINI_API_KEY")
    allow(Line::Messaging).to receive(:channel_access_token).and_return("TEST_LINE_CHANNEL_ACCESS_TOKEN")
    allow(Line::Login).to receive_messages(channel_id: "TEST_LINE_CHANNEL_ID", channel_secret: "TEST_LINE_CHANNEL_SECRET")
  end
end
