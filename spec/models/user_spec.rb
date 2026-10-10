require "rails_helper"

RSpec.describe User do
  def build_user(**attrs)
    User.new(line_user_id: "U1234567890", name: "テスト", **attrs)
  end

  it "LINE のユーザーIDと名前があれば保存できる" do
    expect(build_user).to be_valid
  end

  it "体質を指定しなければ「ふつう」になる" do
    expect(build_user.sensitivity).to eq "normal"
  end

  it "体質は暑がり・寒がりにも変えられる" do
    user = build_user(sensitivity: :cold)

    expect(user).to be_cold
    expect(Sensitivity.label(user.sensitivity)).to eq "寒がり"
  end

  it "LINE のユーザーIDがないと保存できない" do
    expect(build_user(line_user_id: "")).not_to be_valid
  end

  it "名前がないと保存できない" do
    expect(build_user(name: "")).not_to be_valid
  end

  it "同じ LINE のユーザーIDでは2人目を登録できない" do
    build_user.save!

    expect(build_user(name: "2人目")).not_to be_valid
  end
end
