# Gemini の返事を偽物に差し替える（テスト用）
module GeminiStub
  def stub_gemini(home: "今日は羽織りものがあると安心です。", line: "羽織りものを持っていってね🧥")
    body = { candidates: [ { content: { parts: [ { text: { home:, line: }.to_json } ] } } ] }
    stub_request(:post, Gemini::AdviceWriter::ENDPOINT).to_return(status: 200, body: body.to_json)
  end
end

RSpec.configure do |config|
  config.include GeminiStub
end
