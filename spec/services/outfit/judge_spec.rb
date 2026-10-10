require "rails_helper"

RSpec.describe Outfit::Judge do
  # 指定しなければ「最低気温は最高気温の5℃下・降水確率0%・ふつう」で判定する
  def judge(max_temp:, min_temp: max_temp - 5, precipitation_probability: 0, sensitivity: :normal)
    described_class.call(max_temp:, min_temp:, precipitation_probability:, sensitivity:)
  end

  describe "服装" do
    it "最高気温の目安どおりに6段階で判定する" do
      expect(judge(max_temp: 28).outfit).to eq :short_sleeve
      expect(judge(max_temp: 22).outfit).to eq :long_sleeve
      expect(judge(max_temp: 18).outfit).to eq :cardigan
      expect(judge(max_temp: 14).outfit).to eq :light_coat
      expect(judge(max_temp: 10).outfit).to eq :coat
      expect(judge(max_temp: 5).outfit).to eq :heavy_coat
    end

    it "境目の温度ちょうどは、薄着のほうになる" do
      expect(judge(max_temp: 24.9).outfit).to eq :long_sleeve
      expect(judge(max_temp: 25.0).outfit).to eq :short_sleeve
      expect(judge(max_temp: 19.9).outfit).to eq :cardigan
      expect(judge(max_temp: 20.0).outfit).to eq :long_sleeve
      expect(judge(max_temp: 7.9).outfit).to eq :heavy_coat
      expect(judge(max_temp: 8.0).outfit).to eq :coat
    end

    it "氷点下でも厚手コートになる" do
      expect(judge(max_temp: -5).outfit).to eq :heavy_coat
    end

    context "体質で補正する" do
      it "同じ22℃でも、暑がりは半袖、寒がりは長袖＋カーディガンになる" do
        expect(judge(max_temp: 22, sensitivity: :normal).outfit).to eq :long_sleeve
        expect(judge(max_temp: 22, sensitivity: :hot).outfit).to eq :short_sleeve
        expect(judge(max_temp: 22, sensitivity: :cold).outfit).to eq :cardigan
      end

      it "体質は文字列で渡しても判定できる" do
        expect(judge(max_temp: 22, sensitivity: "cold").outfit).to eq :cardigan
      end
    end
  end

  describe "傘" do
    it "降水確率50%以上なら傘あり" do
      expect(judge(max_temp: 20, precipitation_probability: 49).umbrella).to be false
      expect(judge(max_temp: 20, precipitation_probability: 50).umbrella).to be true
    end

    it "降水確率が取れなかった（nil）ときは傘なし" do
      expect(judge(max_temp: 20, precipitation_probability: nil).umbrella).to be false
    end
  end

  describe "暑さの段階" do
    it "気象庁の定義どおり、真夏日・猛暑日・酷暑日を判定する" do
      expect(judge(max_temp: 29.9).heat_level).to be_nil
      expect(judge(max_temp: 30.0).heat_level).to eq :hot_day
      expect(judge(max_temp: 34.9).heat_level).to eq :hot_day
      expect(judge(max_temp: 35.0).heat_level).to eq :very_hot_day
      expect(judge(max_temp: 39.9).heat_level).to eq :very_hot_day
      expect(judge(max_temp: 40.0).heat_level).to eq :extreme_hot_day
    end

    it "体質で補正せず、実際の気温で判定する" do
      expect(judge(max_temp: 28, sensitivity: :hot).heat_level).to be_nil
      expect(judge(max_temp: 31, sensitivity: :cold).heat_level).to eq :hot_day
    end

    it "日本語のラベルを返す" do
      expect(described_class.heat_label(:hot_day)).to eq "真夏日"
      expect(described_class.heat_label(:very_hot_day)).to eq "猛暑日"
      expect(described_class.heat_label(:extreme_hot_day)).to eq "酷暑日"
    end
  end

  describe "寒暖差" do
    it "最高気温と最低気温の差が7℃以上なら寒暖差あり" do
      expect(judge(max_temp: 22, min_temp: 15.1).temperature_gap).to be false
      expect(judge(max_temp: 22, min_temp: 15.0).temperature_gap).to be true
    end

    it "小数の引き算の誤差があっても、ちょうど7℃差なら寒暖差あり" do
      expect(judge(max_temp: 8.2, min_temp: 1.2).temperature_gap).to be true # 8.2 - 1.2 は 6.999… になる
    end
  end
end
