class User < ApplicationRecord
  has_one :location, dependent: :destroy

  enum :sensitivity, Sensitivity::LEVELS

  validates :line_user_id, presence: true, uniqueness: true
  validates :name, presence: true
end
