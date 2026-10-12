class TopController < ApplicationController
  # 初期表示の場所
  DEFAULT_PLACE = Weather::Geocoder::Result.new(name: "東京都渋谷区", latitude: 35.66367, longitude: 139.697723)

  # ログイン中にトップ（/）を開いたら、ホームを出す
  before_action :go_home_if_logged_in, only: :index

  # GET /（ログインしていない人のトップ）
  def index
    show_weather
  end

  # GET /search（しらべる。ログイン中の人も、ほかの場所の天気を調べられる）
  # GET /search?name=東京都中央区&lat=35.67&lon=139.77（候補から選んだとき）
  def search
    show_weather
    render :index
  end

  private

  def show_weather
    @place = selected_place || DEFAULT_PLACE
    @forecast = Weather::Forecast.fetch(latitude: @place.latitude, longitude: @place.longitude)
    # 画面には四捨五入した気温を出すので、判定も同じ値で行う（「25℃なのに長袖」のようなずれを防ぐ）
    @judgment = Outfit::Judge.call(
      max_temp: @forecast.max_temp.round,
      min_temp: @forecast.min_temp.round,
      precipitation_probability: @forecast.precipitation_probability
    )
  rescue Weather::Error
    @error = "天気を取得できませんでした。時間をおいてもう一度お試しください"
  end

  def go_home_if_logged_in
    return unless logged_in?

    redirect_to current_user.location ? home_path : settings_path
  end

  # 候補から選んだ場所。URL に name・lat・lon がそろっていなければ nil
  def selected_place
    return nil if params[:name].blank? || params[:lat].blank? || params[:lon].blank?

    Weather::Geocoder::Result.new(name: params[:name], latitude: params[:lat].to_f, longitude: params[:lon].to_f)
  end
end
