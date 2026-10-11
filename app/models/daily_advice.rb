# その人の、その日のアドバイス（1人1日1件）
class DailyAdvice < ApplicationRecord
  belongs_to :user

  enum :outfit_level, Outfit::LEVELS

  validates :date, presence: true, uniqueness: { scope: :user_id }
  validates :outfit_level, :max_temp, :min_temp, :yesterday_max_temp, presence: true

  # ホームに出す一言。AI に失敗した日（comment が空）は、服装ごとの説明文を使う
  def home_comment
    comment.presence || Outfit.description(outfit_level)
  end

  # LINE に入れる一言。AI に失敗した日（line_comment が空）は、服装ごとの説明文を使う
  def line_message_comment
    line_comment.presence || Outfit.description(outfit_level)
  end
end
