require "rails_helper"

RSpec.describe Weather::Geocoder do
  describe ".search" do
    let(:endpoint) { Weather::Geocoder::ENDPOINT }

    def feature(title, longitude, latitude)
      { geometry: { coordinates: [ longitude, latitude ], type: "Point" },
        type: "Feature", properties: { addressCode: "", title: } }
    end

    def stub_search(query, features)
      stub_request(:get, endpoint).with(query: { q: query }).to_return(status: 200, body: features.to_json)
    end

    it "地名から候補の表示名と緯度・経度を返す" do
      stub_search("中央区", [
        feature("北海道札幌市中央区", 141.354, 43.055),
        feature("東京都中央区", 139.772, 35.670)
      ])

      results = described_class.search("中央区")

      expect(results.map(&:name)).to eq [ "北海道札幌市中央区", "東京都中央区" ]
      expect(results.last).to have_attributes(latitude: 35.670, longitude: 139.772)
    end

    it "川や建物など、都道府県から始まらないものは候補から除く" do
      stub_search("渋谷区", [
        feature("東京都渋谷区", 139.697723, 35.66367),
        feature("渋谷区役所", 139.697717, 35.66367),
        feature("渋谷川", 139.70, 35.65)
      ])

      expect(described_class.search("渋谷区").map(&:name)).to eq [ "東京都渋谷区" ]
    end

    it "同じ座標の候補は1つにまとめる" do
      stub_search("軽井沢町", [
        feature("長野県軽井沢町", 138.596954, 36.348331),
        feature("長野県北佐久郡軽井沢町", 138.596954, 36.348331)
      ])

      expect(described_class.search("軽井沢町").map(&:name)).to eq [ "長野県軽井沢町" ]
    end

    it "候補は最大10件まで" do
      stub_search("中央", (1..12).map { |i| feature("東京都中央#{i}", 139.0 + i, 35.0) })

      expect(described_class.search("中央").size).to eq 10
    end

    it "見つからないときは空の配列を返す" do
      stub_search("あいうえお", [])

      expect(described_class.search("あいうえお")).to eq []
    end

    it "空文字のときは API を呼ばずに空の配列を返す" do
      expect(described_class.search("")).to eq []
      expect(a_request(:get, /msearch\.gsi\.go\.jp/)).not_to have_been_made
    end

    it "タイムアウトしたら Weather::Error を投げる" do
      stub_request(:get, endpoint).with(query: { q: "渋谷区" }).to_timeout

      expect { described_class.search("渋谷区") }.to raise_error(Weather::Error)
    end
  end
end
