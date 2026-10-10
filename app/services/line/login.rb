require "net/http"

module Line
  # LINE ログイン（OAuth 2.0）で LINE とやりとりする窓口。
  # ① ログイン画面の URL を作る → ② 戻ってきた code をユーザー情報（ID と名前）に変える
  module Login
    AUTHORIZE_URL = "https://access.line.me/oauth2/v2.1/authorize".freeze
    TOKEN_URL = "https://api.line.me/oauth2/v2.1/token".freeze
    VERIFY_URL = "https://api.line.me/oauth2/v2.1/verify".freeze
    TIMEOUT_SECONDS = 5

    Profile = Data.define(:line_user_id, :name, :picture_url)

    # LINE とのやりとりに失敗したとき
    class Error < StandardError; end

    # ① LINE のログイン画面の URL。bot_prompt: "aggressive" で、ログインのあとに公式アカウントの友だち追加を出す
    def self.authorize_url(redirect_uri:, state:)
      query = URI.encode_www_form(
        response_type: "code",
        client_id: channel_id,
        redirect_uri:,
        state:,
        scope: "profile openid",
        bot_prompt: "aggressive"
      )
      "#{AUTHORIZE_URL}?#{query}"
    end

    # ② code → アクセストークンと ID トークン → ID トークンを LINE に検証してもらい、ユーザーID（sub）・名前・プロフィール画像を受け取る
    def self.fetch_profile(code:, redirect_uri:)
      token = post_form(TOKEN_URL, grant_type: "authorization_code", code:, redirect_uri:,
                                   client_id: channel_id, client_secret: channel_secret)
      claims = post_form(VERIFY_URL, id_token: token.fetch("id_token"), client_id: channel_id)

      # プロフィール画像を設定していない人は picture がない（nil になる）
      Profile.new(line_user_id: claims.fetch("sub"), name: claims.fetch("name"), picture_url: claims["picture"])
    rescue KeyError => e
      raise Error, "LINE のレスポンスが想定外です: #{e.message}"
    end

    def self.channel_id
      Rails.application.credentials.dig(:line_login, :channel_id).to_s
    end

    def self.channel_secret
      Rails.application.credentials.dig(:line_login, :channel_secret).to_s
    end

    # POST でフォームを送り、JSON をパースして返す。失敗したら Line::Login::Error を投げる
    def self.post_form(url, params)
      uri = URI(url)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                                 open_timeout: TIMEOUT_SECONDS, read_timeout: TIMEOUT_SECONDS) do |http|
        http.post(uri.path, URI.encode_www_form(params), "Content-Type" => "application/x-www-form-urlencoded")
      end
      raise Error, "HTTP #{response.code} (#{uri.path})" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    rescue Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError, JSON::ParserError => e
      raise Error, "#{e.class}: #{e.message}"
    end
    private_class_method :post_form
  end
end
