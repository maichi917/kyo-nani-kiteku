require "net/http"

module Line
  # LINE 公式アカウントからメッセージを送る窓口（Messaging API）
  module Messaging
    PUSH_URL = "https://api.line.me/v2/bot/message/push".freeze
    TIMEOUT_SECONDS = 5

    # 送れなかったとき（友だちでない・ブロックされている・トークンが違うなど）
    class Error < StandardError; end

    # to：送り先の LINE ユーザーID（users.line_user_id）、text：送る文章
    def self.push_text(to:, text:)
      push_texts(to:, texts: [ text ])
    end

    # 1回の送信で、吹き出しを複数（最大5つ）送る。通数は吹き出しの数ではなく、1回の送信 × 人数で数えられる
    def self.push_texts(to:, texts:)
      uri = URI(PUSH_URL)
      body = { to:, messages: texts.map { |text| { type: "text", text: } } }.to_json

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                                 open_timeout: TIMEOUT_SECONDS, read_timeout: TIMEOUT_SECONDS) do |http|
        http.post(uri.path, body, "Content-Type" => "application/json", "Authorization" => "Bearer #{channel_access_token}")
      end
      raise Error, "HTTP #{response.code}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

      true
    rescue Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError => e
      raise Error, "#{e.class}: #{e.message}"
    end

    def self.channel_access_token
      Rails.application.credentials.dig(:line_messaging, :channel_access_token).to_s
    end
  end
end
