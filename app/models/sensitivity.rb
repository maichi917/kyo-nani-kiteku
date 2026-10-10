# 体質（暑がり・ふつう・寒がり）。服装を判定する前の気温の補正に使う
module Sensitivity
  # DB に保存するときの数値。users.sensitivity の enum でも使う（初期値の 0 が「ふつう」）
  LEVELS = {
    normal: 0,
    hot: 1,
    cold: 2
  }.freeze

  LABELS = {
    normal: "ふつう",
    hot: "暑がり",
    cold: "寒がり"
  }.freeze

  # 判定前に最高気温へ足す値。暑がりは実際より暑く、寒がりは実際より寒く感じるものとして扱う
  TEMPERATURE_OFFSETS = {
    normal: 0,
    hot: 3,
    cold: -3
  }.freeze

  def self.label(level)
    LABELS.fetch(level.to_sym)
  end

  def self.temperature_offset(level)
    TEMPERATURE_OFFSETS.fetch(level.to_sym)
  end
end
