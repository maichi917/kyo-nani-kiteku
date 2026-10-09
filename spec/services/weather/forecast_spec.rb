require "rails_helper"

RSpec.describe Weather::Forecast do
  describe ".fetch" do
    let(:request) { stub_request(:get, Weather::Forecast::ENDPOINT).with(query: hash_including(latitude: "35.66", longitude: "139.7", past_days: "1")) }

    it "今日の最高・最低気温、降水確率と昨日の最高気温を返す" do
      request.to_return(
        status: 200,
        body: {
          daily: {
            time: [ "2026-10-08", "2026-10-09" ],
            temperature_2m_max: [ 23.5, 24.4 ],
            temperature_2m_min: [ 15.4, 15.2 ],
            precipitation_probability_max: [ 4, 60 ]
          }
        }.to_json
      )

      result = described_class.fetch(latitude: 35.66, longitude: 139.7)

      expect(result).to have_attributes(
        date: Date.new(2026, 10, 9),
        max_temp: 24.4,
        min_temp: 15.2,
        precipitation_probability: 60,
        yesterday_max_temp: 23.5
      )
    end

    it "API がエラーを返したら Weather::Error を投げる" do
      request.to_return(status: 500, body: "")

      expect { described_class.fetch(latitude: 35.66, longitude: 139.7) }.to raise_error(Weather::Error, /HTTP 500/)
    end

    it "タイムアウトしたら Weather::Error を投げる" do
      request.to_timeout

      expect { described_class.fetch(latitude: 35.66, longitude: 139.7) }.to raise_error(Weather::Error)
    end
  end
end
