require "rails_helper"

RSpec.describe "Settings", type: :request do
  let(:user) { User.create!(line_user_id: "U1234567890", name: "まい") }

  # LINE ログインの流れを、LINE の API を偽物にして通す
  def sign_in(user)
    stub_request(:post, Line::Login::TOKEN_URL).to_return(status: 200, body: { id_token: "dummy" }.to_json)
    stub_request(:post, Line::Login::VERIFY_URL).to_return(status: 200, body: { sub: user.line_user_id, name: user.name }.to_json)
    get line_login_path
    state = Rack::Utils.parse_query(URI(response.location).query).fetch("state")
    get line_callback_path(code: "abc", state:)
  end

  describe "ログインしていないとき" do
    it "設定画面は見られず、トップへ戻る" do
      get settings_path

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq "LINE でログインしてください"
    end

    it "マイエリアは保存できない" do
      expect {
        patch location_path, params: { location: { name: "東京都渋谷区", latitude: 35.66, longitude: 139.69 } }
      }.not_to change(Location, :count)
    end
  end

  describe "GET /settings" do
    before { sign_in(user) }

    it "マイエリアが未設定なら、そのことを伝える" do
      get settings_path

      expect(response.body).to include("まだ設定されていません")
    end

    it "地名で検索すると、候補と「この場所にする」ボタンが出る" do
      stub_request(:get, Weather::Geocoder::ENDPOINT).with(query: { q: "中央区" }).to_return(
        status: 200,
        body: [ { geometry: { coordinates: [ 139.772, 35.670 ], type: "Point" }, type: "Feature", properties: { title: "東京都中央区" } } ].to_json
      )

      get settings_path(q: "中央区")

      expect(response.body).to include("東京都中央区")
      expect(response.body).to include("この場所にする")
    end
  end

  describe "PATCH /location" do
    before { sign_in(user) }

    let(:params) { { location: { name: "東京都中央区", latitude: 35.670, longitude: 139.772 } } }

    it "マイエリアがなければ新しく作る" do
      expect { patch location_path, params: }.to change(Location, :count).by(1)

      expect(user.reload.location.name).to eq "東京都中央区"
      expect(flash[:notice]).to eq "マイエリアを「東京都中央区」に設定しました"
    end

    it "マイエリアがあれば上書きする（2つ目は作らない）" do
      user.create_location!(name: "東京都渋谷区", latitude: 35.66, longitude: 139.69)

      expect { patch location_path, params: }.not_to change(Location, :count)
      expect(user.reload.location.name).to eq "東京都中央区"
    end

    it "ありえない緯度は保存しない" do
      patch location_path, params: { location: { name: "変な場所", latitude: 999, longitude: 139.0 } }

      expect(user.reload.location).to be_nil
      expect(flash[:alert]).to eq "マイエリアを設定できませんでした。もう一度お試しください"
    end
  end

  describe "PATCH /settings" do
    before { sign_in(user) }

    it "体感タイプを保存する" do
      patch settings_path, params: { user: { sensitivity: "cold" } }

      expect(user.reload).to be_cold
      expect(flash[:notice]).to eq "体感タイプを保存しました"
    end

    it "でたらめな値は保存せず、エラー画面にもしない" do
      patch settings_path, params: { user: { sensitivity: "foo" } }

      expect(response).to redirect_to(settings_path)
      expect(user.reload).to be_normal
      expect(flash[:alert]).to eq "体感タイプを保存できませんでした"
    end

    it "体感タイプ以外の項目は受け取らない" do
      patch settings_path, params: { user: { sensitivity: "hot", name: "乗っ取り" } }

      expect(user.reload.name).to eq "まい"
    end
  end
end
