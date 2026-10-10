require "rails_helper"

RSpec.describe "Sessions", type: :request do
  # LINE のトークン発行と ID トークン検証を、偽物の返事に差し替える
  def stub_line_login(sub: "U1234567890", name: "まい", picture: "https://profile.line-scdn.net/example")
    stub_request(:post, Line::Login::TOKEN_URL).to_return(status: 200, body: { id_token: "dummy-id-token" }.to_json)
    stub_request(:post, Line::Login::VERIFY_URL).to_return(status: 200, body: { sub:, name:, picture: }.to_json)
  end

  # 「LINEでログイン」を押して、LINE に渡した state（合言葉）を取り出す
  def start_login
    get line_login_path
    Rack::Utils.parse_query(URI(response.location).query).fetch("state")
  end

  describe "GET /auth/line" do
    it "LINE のログイン画面へ送る。友だち追加も出す" do
      get line_login_path

      expect(response).to redirect_to(%r{\Ahttps://access\.line\.me/oauth2/v2\.1/authorize})
      expect(response.location).to include("bot_prompt=aggressive")
      expect(response.location).to include("state=")
    end
  end

  describe "GET /auth/line/callback" do
    before do
      # トップページの天気は、このテストでは関係ないので偽物にしておく
      stub_request(:get, Weather::Forecast::ENDPOINT).with(query: hash_including({})).to_return(
        status: 200,
        body: { daily: { time: [ "2026-10-09", "2026-10-10" ], temperature_2m_max: [ 23.5, 24.6 ],
                         temperature_2m_min: [ 15.4, 15.2 ], precipitation_probability_max: [ 4, 0 ] } }.to_json
      )
    end

    it "初めての人は users に登録して、ログイン状態にする" do
      stub_line_login
      state = start_login

      expect { get line_callback_path(code: "abc", state:) }.to change(User, :count).by(1)

      user = User.last
      expect(user).to have_attributes(line_user_id: "U1234567890", name: "まい", picture_url: "https://profile.line-scdn.net/example")
      # マイエリアがまだないので、設定画面へ
      expect(response).to redirect_to(settings_path)
      follow_redirect!
      expect(response.body).to include("まずはマイエリアを設定してください")
      expect(response.body).to include("ログアウト")
    end

    it "2回目以降は新しく登録せず、名前とプロフィール画像を最新にする" do
      User.create!(line_user_id: "U1234567890", name: "前の名前")
      stub_line_login(name: "新しい名前", picture: nil)
      state = start_login

      expect { get line_callback_path(code: "abc", state:) }.not_to change(User, :count)
      expect(User.last).to have_attributes(name: "新しい名前", picture_url: nil)
    end

    it "マイエリアを設定済みの人は、ログイン後にトップへ戻る" do
      user = User.create!(line_user_id: "U1234567890", name: "まい")
      user.create_location!(name: "東京都渋谷区", latitude: 35.66367, longitude: 139.697723)
      stub_line_login
      state = start_login

      get line_callback_path(code: "abc", state:)

      expect(response).to redirect_to(root_path)
    end

    it "state が違うときはログインさせず、LINE にも問い合わせない" do
      stub_line_login
      start_login

      expect { get line_callback_path(code: "abc", state: "wrong") }.not_to change(User, :count)
      expect(flash[:alert]).to eq "ログインに失敗しました。もう一度お試しください"
      expect(a_request(:post, Line::Login::TOKEN_URL)).not_to have_been_made
    end

    it "LINE の画面でキャンセルしたときは、メッセージを出してトップに戻す" do
      state = start_login

      get line_callback_path(error: "access_denied", state:)

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq "LINE ログインをキャンセルしました"
    end

    it "LINE とのやりとりに失敗したときは、メッセージを出してトップに戻す" do
      stub_request(:post, Line::Login::TOKEN_URL).to_return(status: 400)
      state = start_login

      expect { get line_callback_path(code: "abc", state:) }.not_to change(User, :count)
      expect(flash[:alert]).to eq "ログインに失敗しました。もう一度お試しください"
    end
  end

  describe "DELETE /logout" do
    it "ログアウトする" do
      stub_line_login
      state = start_login
      get line_callback_path(code: "abc", state:)

      delete logout_path

      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to eq "ログアウトしました"
      expect(session[:user_id]).to be_nil
    end
  end
end
