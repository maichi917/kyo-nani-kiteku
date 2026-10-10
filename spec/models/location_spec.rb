require "rails_helper"

RSpec.describe Location do
  let(:user) { User.create!(line_user_id: "U1234567890", name: "テスト") }

  def build_location(**attrs)
    Location.new(user:, name: "東京都渋谷区", latitude: 35.66367, longitude: 139.697723, **attrs)
  end

  it "地名・緯度・経度があれば保存できる" do
    expect(build_location).to be_valid
  end

  it "地名がないと保存できない" do
    expect(build_location(name: "")).not_to be_valid
  end

  it "ありえない緯度・経度は保存できない" do
    expect(build_location(latitude: 91)).not_to be_valid
    expect(build_location(longitude: -181)).not_to be_valid
  end

  it "ユーザーから自宅、自宅からユーザーをたどれる" do
    location = build_location
    location.save!

    expect(user.reload.location).to eq location
    expect(location.user).to eq user
  end

  it "ユーザーを削除すると、自宅も削除される" do
    build_location.save!

    expect { user.destroy }.to change(Location, :count).by(-1)
  end
end
