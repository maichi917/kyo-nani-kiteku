require "rails_helper"

RSpec.describe "Places", type: :request do
  def stub_geocoder(query, titles)
    features = titles.each_with_index.map do |title, i|
      { geometry: { coordinates: [ 139.0 + i, 35.0 + i ], type: "Point" }, type: "Feature", properties: { title: } }
    end
    stub_request(:get, Weather::Geocoder::ENDPOINT).with(query: { q: query }).to_return(status: 200, body: features.to_json)
  end

  describe "GET /places" do
    it "候補リストを Turbo Frame の中に返す" do
      stub_geocoder("中央区", [ "北海道札幌市中央区", "東京都中央区" ])

      get places_path(q: "中央区")

      expect(response.body).to include('<turbo-frame id="place_candidates">')
      expect(response.body).to include("北海道札幌市中央区")
      expect(response.body).to include("東京都中央区")
    end

    it "候補のリンクは、選ぶとページごと切り替わる（_top）" do
      stub_geocoder("中央区", [ "東京都中央区" ])

      get places_path(q: "中央区")

      expect(response.body).to include('data-turbo-frame="_top"')
      expect(response.body).to include("lat=35.0")
      expect(response.body).to include("lon=139.0")
    end

    it "見つからないときはメッセージを出す" do
      stub_geocoder("あいうえお", [])

      get places_path(q: "あいうえお")

      expect(response.body).to include("見つかりませんでした")
    end

    it "何も入力していないときは、API を呼ばずに何も出さない" do
      get places_path(q: "")

      expect(response.body).not_to include("見つかりませんでした")
      expect(a_request(:get, /msearch\.gsi\.go\.jp/)).not_to have_been_made
    end

    it "国土地理院が失敗したら、エラー画面にせずメッセージを出す" do
      stub_request(:get, Weather::Geocoder::ENDPOINT).with(query: { q: "中央区" }).to_timeout

      get places_path(q: "中央区")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("地名を検索できませんでした")
    end
  end
end
