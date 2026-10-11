require "net/http"

module Gemini
  # Gemini に、ホーム用と LINE 用の一言を1回の呼び出しで書いてもらう
  module AdviceWriter
    MODEL = "gemini-3.5-flash-lite".freeze
    ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models/#{MODEL}:generateContent".freeze
    TIMEOUT_SECONDS = 15 # 文章を作るので、天気の API より長めに待つ

    Result = Data.define(:home, :line)

    # AI に失敗したとき（タイムアウト・エラー・想定外の返事）
    class Error < StandardError; end

    # weather：場所や気温などの材料（Hash）。返り値は Result（home と line の2つの文）
    def self.write(weather)
      response = post_json(
        contents: [ { parts: [ { text: prompt(weather) } ] } ],
        generationConfig: {
          # 返事を、決まった形の JSON にしてもらう
          responseMimeType: "application/json",
          responseSchema: {
            type: "OBJECT",
            properties: { home: { type: "STRING" }, line: { type: "STRING" } },
            required: %w[home line]
          }
        }
      )
      text = response.dig("candidates", 0, "content", "parts", 0, "text")
      json = JSON.parse(text.to_s)

      Result.new(home: json.fetch("home").strip, line: json.fetch("line").strip)
    rescue JSON::ParserError, KeyError, NoMethodError => e
      raise Error, "Gemini の返事が想定外です: #{e.message}"
    end

    def self.prompt(weather)
      <<~PROMPT
        あなたは「今日なにちゃん」です。毎朝、友だちにその日の服装をアドバイスしています。
        - 一人称：わたし
        - 口調：「〜だよ！」「〜してね☀️」のように、明るく親しみやすく
        - 性格：明るくて、ちょっとおせっかい。友だちの服装が気になってしかたない

        下の「今日の天気と服装」をもとに、2つの一言を書いてください。

        # 今日の天気と服装
        - 場所：#{weather[:place_name]}
        - 最高気温：#{weather[:max_temp]}℃（昨日は#{weather[:yesterday_max_temp]}℃）
        - 最低気温：#{weather[:min_temp]}℃
        - 降水確率：#{weather[:precipitation_probability]}%#{weather[:umbrella] ? '（傘が必要）' : ''}
        - おすすめの服装：#{weather[:outfit]}
        - 体感タイプ：#{weather[:sensitivity]}
        - 注意：#{weather[:notices].presence&.join('、') || 'とくになし'}

        # 書いてほしいもの
        - home：アプリの画面に出す一言。今日なにちゃんではなく、アプリからのやさしい一言として書く。40〜60字。やわらかい丁寧語（「〜です」「〜ましょう」）で、「お持ちください」「お過ごしください」のようなかたい言い回しは使わない。あいさつは入れない。場所の名前は書かない（画面に出ているので）。絵文字は使わない。改行しない
        - line：LINE で届く一言。今日なにちゃんとして話す。「おはよう！今日なにちゃんだよ☀️」で始める。60〜100字（あいさつは数えない）。絵文字を2〜3個使う。スマホで読みやすいように、1〜2文ごとに改行する

        # 守ってほしいこと
        - 服装・寒暖差・暑さ・雨のうち、今日いちばん大事なことに触れる
        - 気温や降水確率の数字は書かない（数字は別の場所に出すので、気持ちやアドバイスを書く）
        - 天気を勝手に足さない
        - おすすめの服装の「あたたかさの段階」は変えない。ただし具体的な服は言い換えてよい（例：カーディガン → シャツやパーカーなどの羽織りもの）
        - 寒暖差がある日は、日中の服に、朝晩用の羽織りものを足すアドバイスをしてよい
      PROMPT
    end

    def self.api_key
      Rails.application.credentials.dig(:gemini, :api_key).to_s
    end

    def self.post_json(body)
      uri = URI(ENDPOINT)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                                 open_timeout: TIMEOUT_SECONDS, read_timeout: TIMEOUT_SECONDS) do |http|
        http.post(uri.path, body.to_json, "Content-Type" => "application/json", "x-goog-api-key" => api_key)
      end
      raise Error, "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    rescue Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError, JSON::ParserError => e
      raise Error, "#{e.class}: #{e.message}"
    end
    private_class_method :post_json
  end
end
