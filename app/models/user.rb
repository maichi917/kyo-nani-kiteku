class User < ApplicationRecord
  has_one :location, dependent: :destroy

  # validate: true で、決められた値以外が来たらエラー画面にせず、保存できないだけにする
  enum :sensitivity, Sensitivity::LEVELS, validate: true

  validates :line_user_id, presence: true, uniqueness: true
  validates :name, presence: true
end
