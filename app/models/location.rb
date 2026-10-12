# ユーザーのマイエリア（毎朝の通知に使う場所。自宅を想定しているが、職場などでもよい）
class Location < ApplicationRecord
  belongs_to :user

  validates :name, presence: true
  validates :latitude, presence: true, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }
  validates :longitude, presence: true, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }

  # 都道府県を外した短い名前（例：愛知県名古屋市 → 名古屋市、愛知県名古屋市中区 → 名古屋市中区）。LINE の一言の書き出しに使う
  def short_name
    name.sub(Weather::Geocoder::ADDRESS_PATTERN, "").presence || name
  end
end
