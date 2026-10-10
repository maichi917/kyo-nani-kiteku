# ユーザーのマイエリア（毎朝の通知に使う場所。自宅を想定しているが、職場などでもよい）
class Location < ApplicationRecord
  belongs_to :user

  validates :name, presence: true
  validates :latitude, presence: true, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }
  validates :longitude, presence: true, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }
end
