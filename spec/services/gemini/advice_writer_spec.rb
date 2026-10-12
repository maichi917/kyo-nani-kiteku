require "rails_helper"

RSpec.describe Gemini::AdviceWriter do
  let(:weather) do
    { place_name: "東京都渋谷区", short_place_name: "渋谷区", max_temp: 22, yesterday_max_temp: 26, min_temp: 13,
      precipitation_probability: 60, umbrella: true, outfit: "長袖＋カーディガン", sensitivity: "寒がり", notices: [ "寒暖差あり" ] }
  end

  describe ".write" do
    it "Gemini の返事から、ホーム用と LINE 用の一言を取り出す" do
      stub_gemini(home: "  ホーム用の一言です。  ", line: "今日の渋谷区はひんやりしそう！\n羽織りものを持っていってね🧥")

      result = described_class.write(weather)

      expect(result.home).to eq "ホーム用の一言です。"
      expect(result.line).to eq "今日の渋谷区はひんやりしそう！\n羽織りものを持っていってね🧥"
    end

    it "天気と服装をお願いの文に入れ、JSON で返すように頼む" do
      stub_gemini

      described_class.write(weather)

      expect(
        a_request(:post, Gemini::AdviceWriter::ENDPOINT).with do |req|
          body = JSON.parse(req.body)
          prompt = body.dig("contents", 0, "parts", 0, "text")
          prompt.include?("今日の渋谷区は") && prompt.include?("長袖＋カーディガン") && prompt.include?("寒暖差あり") &&
            body.dig("generationConfig", "responseMimeType") == "application/json"
        end
      ).to have_been_made.once
    end

    it "Gemini がエラーを返したら Gemini::AdviceWriter::Error を投げる" do
      stub_request(:post, Gemini::AdviceWriter::ENDPOINT).to_return(status: 503, body: "")

      expect { described_class.write(weather) }.to raise_error(Gemini::AdviceWriter::Error, /HTTP 503/)
    end

    it "タイムアウトしたら Gemini::AdviceWriter::Error を投げる" do
      stub_request(:post, Gemini::AdviceWriter::ENDPOINT).to_timeout

      expect { described_class.write(weather) }.to raise_error(Gemini::AdviceWriter::Error)
    end

    it "返事の形が想定外なら Gemini::AdviceWriter::Error を投げる" do
      stub_request(:post, Gemini::AdviceWriter::ENDPOINT).to_return(status: 200, body: { candidates: [] }.to_json)

      expect { described_class.write(weather) }.to raise_error(Gemini::AdviceWriter::Error, /想定外/)
    end
  end
end
