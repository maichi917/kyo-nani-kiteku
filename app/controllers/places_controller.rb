class PlacesController < ApplicationController
  # GET /places?q=中央区
  # 検索欄の下の候補リスト（Turbo Frame の中身）を返す
  def index
    @query = params[:q].to_s.strip
    @places = Weather::Geocoder.search(@query)
  rescue Weather::Error
    @places = []
    @error = "地名を検索できませんでした。時間をおいてもう一度お試しください"
  end
end
