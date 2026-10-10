class SettingsController < ApplicationController
  before_action :require_login

  # GET /settings
  # GET /settings?q=中央区（自宅の候補を検索したとき）
  def show
    @location = current_user.location
    @query = params[:q].to_s.strip
    @places = Weather::Geocoder.search(@query)
  rescue Weather::Error
    @places = []
    @search_error = "地名を検索できませんでした。時間をおいてもう一度お試しください"
  end

  # PATCH /settings（体感タイプ＝暑がり・ふつう・寒がりを保存する）
  def update
    if current_user.update(settings_params)
      redirect_to settings_path, notice: "体感タイプを保存しました"
    else
      redirect_to settings_path, alert: "体感タイプを保存できませんでした"
    end
  end

  private

  # 受け取ってよい項目だけに絞る（ストロングパラメーター）
  def settings_params
    params.expect(user: [ :sensitivity ])
  end
end
