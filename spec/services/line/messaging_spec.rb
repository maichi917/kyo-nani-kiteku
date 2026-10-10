require "rails_helper"

RSpec.describe Line::Messaging do
  describe ".push_text" do
    before { allow(described_class).to receive(:channel_access_token).and_return("TEST_TOKEN") }

    it "宛先と文章を、トークン付きで LINE に送る" do
      stub_request(:post, Line::Messaging::PUSH_URL).to_return(status: 200, body: "{}")

      described_class.push_text(to: "U1234567890", text: "おはようございます")

      expect(
        a_request(:post, Line::Messaging::PUSH_URL).with(
          headers: { "Authorization" => "Bearer TEST_TOKEN", "Content-Type" => "application/json" },
          body: { to: "U1234567890", messages: [ { type: "text", text: "おはようございます" } ] }.to_json
        )
      ).to have_been_made.once
    end

    it "LINE がエラーを返したら Line::Messaging::Error を投げる" do
      stub_request(:post, Line::Messaging::PUSH_URL).to_return(status: 400, body: '{"message":"Failed to send messages"}')

      expect { described_class.push_text(to: "U1234567890", text: "テスト") }
        .to raise_error(Line::Messaging::Error, /HTTP 400/)
    end

    it "タイムアウトしたら Line::Messaging::Error を投げる" do
      stub_request(:post, Line::Messaging::PUSH_URL).to_timeout

      expect { described_class.push_text(to: "U1234567890", text: "テスト") }.to raise_error(Line::Messaging::Error)
    end
  end
end
