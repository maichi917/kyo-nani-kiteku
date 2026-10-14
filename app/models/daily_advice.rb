# その人の、その日のアドバイス（1人1日1件）
class DailyAdvice < ApplicationRecord
  belongs_to :user

  enum :outfit_level, Outfit::LEVELS

  validates :date, presence: true, uniqueness: { scope: :user_id }
  validates :outfit_level, :max_temp, :min_temp, :yesterday_max_temp, presence: true

  # 今日のアドバイスを返す。なければ、天気・服装の判定・AI の一言をそろえて作る
  # （ホーム画面と毎朝のジョブから使う。天気が取れなければ Weather::Error）
  def self.for_today(user)
    user.daily_advices.find_by(date: Date.current) || create_for_today(user)
  end

  def self.create_for_today(user)
    location = user.location
    forecast = Weather::Forecast.fetch(latitude: location.latitude, longitude: location.longitude)
    judgment = judge(forecast, sensitivity: user.sensitivity)
    comments = write_comments(location:, forecast:, judgment:, sensitivity: user.sensitivity)

    user.daily_advices.create!(
      date: Date.current,
      outfit_level: judgment.outfit,
      comment: comments&.home,
      line_comment: comments&.line,
      max_temp: forecast.max_temp,
      min_temp: forecast.min_temp,
      yesterday_max_temp: forecast.yesterday_max_temp,
      precipitation_probability: forecast.precipitation_probability
    )
  rescue ActiveRecord::RecordNotUnique
    # ホームとジョブが同時に作ろうとしたときは、先にできたほうを使う
    user.daily_advices.find_by!(date: Date.current)
  end

  # 画面と同じく、四捨五入した気温で、体感タイプも入れて判定する
  def self.judge(forecast, sensitivity:)
    Outfit::Judge.call(
      max_temp: forecast.max_temp.round,
      min_temp: forecast.min_temp.round,
      precipitation_probability: forecast.precipitation_probability,
      sensitivity:
    )
  end

  # AI にひとことを書いてもらう。失敗したら nil（ひとことは空のまま保存し、服装ごとの説明文で代わりにする）
  def self.write_comments(location:, forecast:, judgment:, sensitivity:)
    notices = []
    notices << Outfit::Judge.heat_label(judgment.heat_level) if judgment.heat_level
    notices << "寒暖差あり" if judgment.temperature_gap

    Gemini::AdviceWriter.write(
      place_name: location.name,
      short_place_name: location.short_name,
      max_temp: forecast.max_temp.round,
      yesterday_max_temp: forecast.yesterday_max_temp.round,
      min_temp: forecast.min_temp.round,
      precipitation_probability: forecast.precipitation_probability.to_i,
      umbrella: judgment.umbrella,
      outfit: Outfit.label(judgment.outfit),
      sensitivity: Sensitivity.label(sensitivity),
      notices:
    )
  rescue Gemini::AdviceWriter::Error => e
    Rails.logger.warn("[DailyAdvice] AI のひとことを作れませんでした（説明文で代わりにします）: #{e.message}")
    nil
  end
  private_class_method :create_for_today

  # AI のひとことがないとき（作ったときに Gemini が混んでいた日など）、もう一度書いてもらう。
  # 保存してある天気から判定し直して頼む。ひとことがそろっていれば true、また失敗したら false
  def fill_missing_comments!
    return true if line_comment.present?

    judgment = self.class.judge(self, sensitivity: user.sensitivity)
    comments = self.class.write_comments(location: user.location, forecast: self, judgment:, sensitivity: user.sensitivity)
    return false unless comments

    update!(comment: comments.home, line_comment: comments.line)
    true
  end

  # ホームに出す一言。AI に失敗した日（comment が空）は、服装ごとの説明文を使う
  def home_comment
    comment.presence || Outfit.description(outfit_level)
  end

  # LINE の1つ目の吹き出し。今日なにちゃんのあいさつはアプリが入れて、改行の位置を毎日そろえる。
  # AI に失敗した日（line_comment が空）は、ふつうのあいさつ＋服装ごとの説明文を使う
  def line_message_comment
    if line_comment.present?
      "おはよう！\n今日なにちゃんだよ☀️\n\n#{line_comment}"
    else
      "おはようございます☀️\n#{Outfit.description(outfit_level)}"
    end
  end
end
