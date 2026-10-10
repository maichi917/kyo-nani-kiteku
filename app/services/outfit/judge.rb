module Outfit
  # 最高気温・降水確率・体質から、おすすめの服装と傘・暑さのマークを決める
  class Judge
    # 補正後の最高気温が「この温度以上」なら、その服装。上から順に見て、最初に当てはまったものを使う
    THRESHOLDS = [
      [ 25, :short_sleeve ],
      [ 20, :long_sleeve ],
      [ 16, :cardigan ],
      [ 12, :light_coat ],
      [ 8, :coat ]
    ].freeze
    COLDEST = :heavy_coat # どれにも当てはまらない（8℃未満）とき

    UMBRELLA_PROBABILITY = 50 # 降水確率（%）がこれ以上なら傘

    # 暑さの段階。気象庁の定義（真夏日・猛暑日・酷暑日）に合わせ、実際の最高気温で上から順に判定する
    HEAT_LEVELS = [
      [ 40, :extreme_hot_day ],
      [ 35, :very_hot_day ],
      [ 30, :hot_day ]
    ].freeze
    HEAT_LABELS = {
      extreme_hot_day: "酷暑日",
      very_hot_day: "猛暑日",
      hot_day: "真夏日"
    }.freeze

    # 最高気温と最低気温の差（℃）がこれ以上なら寒暖差あり。寒暖差疲労が出やすいとされる目安
    TEMPERATURE_GAP = 7

    Result = Data.define(:outfit, :umbrella, :heat_level, :temperature_gap)

    def self.call(max_temp:, min_temp:, precipitation_probability:, sensitivity: :normal)
      felt_temp = max_temp + Sensitivity.temperature_offset(sensitivity)

      Result.new(
        outfit: outfit_for(felt_temp),
        # 降水確率が取れなかった日（nil）は 0% として扱う
        umbrella: precipitation_probability.to_i >= UMBRELLA_PROBABILITY,
        # 暑さの段階は体質で補正せず、実際の気温で判定する。30℃未満なら nil
        heat_level: HEAT_LEVELS.find { |threshold, _level| max_temp >= threshold }&.last,
        # 小数どうしの引き算の誤差（9.9999…）を避けるため、小数第1位に丸めて比べる
        temperature_gap: (max_temp - min_temp).round(1) >= TEMPERATURE_GAP
      )
    end

    def self.heat_label(heat_level)
      HEAT_LABELS.fetch(heat_level.to_sym)
    end

    def self.outfit_for(temp)
      THRESHOLDS.find { |min_temp, _outfit| temp >= min_temp }&.last || COLDEST
    end
    private_class_method :outfit_for
  end
end
