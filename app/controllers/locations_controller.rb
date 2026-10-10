class LocationsController < ApplicationController
  before_action :require_login

  # PATCH /location（設定画面で候補から選んだ場所を、マイエリアとして保存する）
  def update
    # まだマイエリアがなければ新しく作り、あれば上書きする（1人1つ）
    location = current_user.location || current_user.build_location

    if location.update(location_params)
      redirect_to settings_path, notice: "マイエリアを「#{location.name}」に設定しました"
    else
      redirect_to settings_path, alert: "マイエリアを設定できませんでした。もう一度お試しください"
    end
  end

  private

  def location_params
    params.expect(location: %i[name latitude longitude])
  end
end
