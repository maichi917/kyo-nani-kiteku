class User < ApplicationRecord
  enum :sensitivity, Sensitivity::LEVELS

  validates :line_user_id, presence: true, uniqueness: true
  validates :name, presence: true
end
