# おすすめの服装（6段階）。薄着から厚着の順に並べている
module Outfit
  # DB に保存するときの数値。daily_advices.outfit_level の enum でも使う
  LEVELS = {
    short_sleeve: 0,
    long_sleeve: 1,
    cardigan: 2,
    light_coat: 3,
    coat: 4,
    heavy_coat: 5
  }.freeze

  LABELS = {
    short_sleeve: "半袖",
    long_sleeve: "長袖1枚",
    cardigan: "長袖＋カーディガン",
    light_coat: "薄手コート",
    coat: "コート",
    heavy_coat: "厚手コート"
  }.freeze

  def self.label(level)
    LABELS.fetch(level.to_sym)
  end
end
