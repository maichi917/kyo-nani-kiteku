require "rails_helper"

RSpec.describe "OGP", type: :request do
  it "どのページにも、共有したときの説明の文と画像（OGP）のタグが入っている" do
    get privacy_path

    expect(response.body).to include('<meta name="description" content="毎朝7時に、今日の天気とおすすめの服装をLINEでお届けします！')
    expect(response.body).to include('<meta property="og:title" content="プライバシーポリシー | 今日なに着てく？">')
    expect(response.body).to include('<meta property="og:url" content="http://www.example.com/privacy">')
    expect(response.body).to include('<meta property="og:image" content="http://www.example.com/ogp.jpg">')
    expect(response.body).to include('<meta name="twitter:card" content="summary_large_image">')
  end
end
