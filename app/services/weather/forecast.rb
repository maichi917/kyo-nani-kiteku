module Weather
  # 緯度・経度から今日の天気と昨日の最高気温を取得する（Open-Meteo）
  class Forecast
    ENDPOINT = "https://api.open-meteo.com/v1/forecast".freeze

    Result = Data.define(:date, :max_temp, :min_temp, :precipitation_probability, :yesterday_max_temp)

    def self.fetch(latitude:, longitude:)
      daily = HttpClient.get_json(
        ENDPOINT,
        latitude:,
        longitude:,
        timezone: "Asia/Tokyo",
        past_days: 1,
        forecast_days: 1,
        daily: "temperature_2m_max,temperature_2m_min,precipitation_probability_max"
      ).fetch("daily")

      # past_days: 1 で昨日の天気も取ってきているため、各配列には [昨日の値, 今日の値] の2つが入っている。
      # .first が昨日、.last が今日
      Result.new(
        date: Date.parse(daily["time"].last),
        max_temp: daily["temperature_2m_max"].last,
        min_temp: daily["temperature_2m_min"].last,
        precipitation_probability: daily["precipitation_probability_max"].last,
        yesterday_max_temp: daily["temperature_2m_max"].first
      )
    rescue KeyError, TypeError, Date::Error => e
      raise Error, "Open-Meteo のレスポンスが想定外です: #{e.message}"
    end
  end
end
