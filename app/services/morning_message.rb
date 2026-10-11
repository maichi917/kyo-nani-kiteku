# 毎朝 LINE に送る通知の文面を作る（今日なにちゃんの一言 ＋ 天気のまとめ）
class MorningMessage
  HEAT_LINES = {
    hot_day: "☀️ 真夏日。こまめに水分補給を",
    very_hot_day: "🥵 猛暑日。熱中症に気をつけて",
    extreme_hot_day: "🔥 酷暑日。外出はできるだけ控えて"
  }.freeze

  # ユーザーの今日のアドバイス（なければ作る）から、文面を作る。天気が取れなければ Weather::Error
  def self.for(user)
    new(place_name: user.location.name, advice: DailyAdvice.for_today(user)).text
  end

  def initialize(place_name:, advice:)
    @place_name = place_name
    @advice = advice
    # 傘・暑さ・寒暖差は、保存した気温から判定し直す（体感タイプは関係しない）
    @judgment = Outfit::Judge.call(
      max_temp: advice.max_temp.round,
      min_temp: advice.min_temp.round,
      precipitation_probability: advice.precipitation_probability
    )
  end

  def text
    [
      @advice.line_message_comment,
      [ weather_lines, notice_lines ].join("\n"),
      "▼ アプリで詳しく見る\n#{Rails.configuration.x.app_url}"
    ].join("\n\n")
  end

  private

  def weather_lines
    max = @advice.max_temp.round
    diff = max - @advice.yesterday_max_temp.round
    compared = if diff.zero?
      "昨日と同じくらい"
    else
      "昨日より#{diff.abs}℃#{diff.positive? ? '高い' : '低い'}"
    end

    [
      "📍 #{@place_name}",
      "🌡 最高#{max}℃ ／ 最低#{@advice.min_temp.round}℃（#{compared}）",
      "☔️ 降水確率 #{@advice.precipitation_probability.to_i}%",
      "👕 おすすめ：#{Outfit.label(@advice.outfit_level)}"
    ].join("\n")
  end

  # 傘・暑さ・寒暖差のお知らせ
  def notice_lines
    lines = [ @judgment.umbrella ? "🌂 雨の可能性あり！傘を持っていこう" : "☀️ 今日は雨は降らなさそうです！" ]
    lines << HEAT_LINES.fetch(@judgment.heat_level) if @judgment.heat_level
    lines << "🧥 寒暖差あり。羽織るものがあると安心" if @judgment.temperature_gap
    lines.join("\n")
  end
end
