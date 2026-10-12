class HomeController < ApplicationController
  before_action :require_login
  before_action :require_location

  # GET /home
  # マイエリアの今日のアドバイス（LINE で届いたものと同じノート）を表示する
  def show
    @location = current_user.location
    @advice = DailyAdvice.for_today(current_user)
    # 傘・暑さ・寒暖差は、保存した気温から判定し直す（服装はアドバイスに保存したものを使う）
    @judgment = Outfit::Judge.call(
      max_temp: @advice.max_temp.round,
      min_temp: @advice.min_temp.round,
      precipitation_probability: @advice.precipitation_probability
    )
  rescue Weather::Error
    @error = "天気を取得できませんでした。時間をおいてもう一度お試しください"
  end

  private

  # マイエリアがまだなければ、設定画面へ案内する
  def require_location
    return if current_user.location

    redirect_to settings_path, notice: "まずはマイエリアを設定してください"
  end
end
