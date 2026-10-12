class User < ApplicationRecord
  has_one :location, dependent: :destroy
  has_many :daily_advices, dependent: :destroy

  # validate: true で、決められた値以外が来たらエラー画面にせず、保存できないだけにする
  enum :sensitivity, Sensitivity::LEVELS, validate: true

  validates :line_user_id, presence: true, uniqueness: true
  validates :name, presence: true

  # 今日のアドバイスを消す。マイエリアや体感タイプを変えたときに呼ぶと、次にホームを開いたときに作り直される
  def reset_today_advice!
    daily_advices.where(date: Date.current).delete_all
  end
end
