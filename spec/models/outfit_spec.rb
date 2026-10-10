require "rails_helper"

RSpec.describe Outfit do
  it "6段階すべてに日本語の名前と説明文がある" do
    Outfit::LEVELS.each_key do |level|
      expect(Outfit.label(level)).to be_present
      expect(Outfit.description(level)).to be_present
    end
  end

  it "文字列で渡しても名前と説明文を返す" do
    expect(Outfit.label("cardigan")).to eq "長袖＋カーディガン"
    expect(Outfit.description("cardigan")).to include "カーディガン"
  end
end
