require "rails_helper"

RSpec.describe "Top", type: :request do
  describe "GET /" do
    it "トップページが表示される" do
      # Open-Meteo を偽物の返事に差し替える
      stub_request(:get, Weather::Forecast::ENDPOINT).with(query: hash_including({})).to_return(
        status: 200,
        body: { daily: { time: [ "2026-10-09", "2026-10-10" ], temperature_2m_max: [ 23.5, 24.6 ],
                         temperature_2m_min: [ 15.4, 15.2 ], precipitation_probability_max: [ 4, 0 ] } }.to_json
      )

      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("今日なに着てく？")
    end
  end
end
