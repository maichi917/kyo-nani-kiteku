# 毎朝 LINE に送る通知の文面を作る
class MorningMessage
  HEAT_LINES = {
    hot_day: "☀️ 真夏日。こまめに水分補給を",
    very_hot_day: "🥵 猛暑日。熱中症に気をつけて",
    extreme_hot_day: "🔥 酷暑日。外出はできるだけ控えて"
  }.freeze

  # ユーザーのマイエリアの天気を取得して、文面を作る。天気が取れなければ Weather::Error
  def self.for(user)
    location = user.location
    forecast = Weather::Forecast.fetch(latitude: location.latitude, longitude: location.longitude)
    # 画面と同じく、四捨五入した気温で、体感タイプも入れて判定する
    judgment = Outfit::Judge.call(
      max_temp: forecast.max_temp.round,
      min_temp: forecast.min_temp.round,
      precipitation_probability: forecast.precipitation_probability,
      sensitivity: user.sensitivity
    )
    # AI の一言（#7）ができるまでは、服装ごとの説明文を使う
    comment = Outfit.description(judgment.outfit)

    new(place_name: location.name, forecast:, judgment:, comment:).text
  end

  def initialize(place_name:, forecast:, judgment:, comment:)
    @place_name = place_name
    @forecast = forecast
    @judgment = judgment
    @comment = comment
  end

  def text
    [
      "おはようございます☀️\n今日なに着てく？👕",
      weather_lines,
      "👕 おすすめ：#{Outfit.label(@judgment.outfit)}\n#{@comment}",
      notice_lines,
      "▼ アプリで詳しく見る\n#{Rails.configuration.x.app_url}"
    ].join("\n\n")
  end

  private

  def weather_lines
    max = @forecast.max_temp.round
    diff = max - @forecast.yesterday_max_temp.round
    compared = if diff.zero?
      "昨日と同じくらい"
    else
      "昨日より#{diff.abs}℃#{diff.positive? ? '高い' : '低い'}"
    end

    [
      "📍 #{@place_name}",
      "🌡 最高#{max}℃ ／ 最低#{@forecast.min_temp.round}℃（#{compared}）",
      "☔️ 降水確率 #{@forecast.precipitation_probability.to_i}%"
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
