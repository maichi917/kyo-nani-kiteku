module Weather
  # 地名から緯度・経度の候補を調べる（国土地理院 地名検索API）
  class Geocoder
    ENDPOINT = "https://msearch.gsi.go.jp/address-search/AddressSearch".freeze
    MAX_CANDIDATES = 10
    # 「東京都渋谷区」のように都道府県から始まるものだけを住所とみなし、川・山・建物などを除く
    ADDRESS_PATTERN = /\A(?:北海道|東京都|京都府|大阪府|.{2,3}県)/

    # 名前、緯度、経度の3つを持つ箱の型を定義
    Result = Data.define(:name, :latitude, :longitude)

    # 候補を最大10件返す。見つからなければ空の配列
    def self.search(query)
      return [] if query.blank?

      HttpClient.get_json(ENDPOINT, q: query)
        .select { |feature| feature.dig("properties", "title").to_s.match?(ADDRESS_PATTERN) }
        .uniq { |feature| feature.dig("geometry", "coordinates") }
        .first(MAX_CANDIDATES)
        .map { |feature| to_result(feature) }
    end

    def self.to_result(feature)
      # 国土地理院は [経度, 緯度] の順で返す
      longitude, latitude = feature.dig("geometry", "coordinates")
      Result.new(name: feature.dig("properties", "title"), latitude:, longitude:)
    end
    private_class_method :to_result
  end
end
