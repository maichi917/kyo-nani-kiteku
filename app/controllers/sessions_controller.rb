class SessionsController < ApplicationController
  # GET /auth/line
  # LINE のログイン画面へ送る
  def new
    # なりすまし対策の合言葉。LINE から戻ってきたときに同じ値かどうか確かめる
    session[:line_login_state] = SecureRandom.hex(16)

    redirect_to Line::Login.authorize_url(redirect_uri: line_callback_url, state: session[:line_login_state]),
                allow_other_host: true
  end

  # GET /auth/line/callback?code=…&state=…
  # LINE でログインしたあと、ここに戻ってくる
  def callback
    expected_state = session.delete(:line_login_state)

    # ユーザーが LINE の画面でキャンセルしたとき
    return redirect_to(root_path, alert: "LINE ログインをキャンセルしました") if params[:code].blank?

    # 自分が送り出したログインから戻ってきたか確かめる（state が違えば、別の誰かが仕掛けたリクエストかもしれない）
    unless expected_state.present? && ActiveSupport::SecurityUtils.secure_compare(expected_state, params[:state].to_s)
      return redirect_to(root_path, alert: "ログインに失敗しました。もう一度お試しください")
    end

    profile = Line::Login.fetch_profile(code: params[:code], redirect_uri: line_callback_url)
    # 初めての人は作り、2回目以降の人は名前とプロフィール画像を最新にする
    user = User.find_or_initialize_by(line_user_id: profile.line_user_id)
    user.update!(name: profile.name, picture_url: profile.picture_url)

    reset_session # ログインの前後でセッションを作り直す（セッション固定攻撃の対策）
    session[:user_id] = user.id
    redirect_to root_path, notice: "ログインしました"
  rescue Line::Login::Error
    redirect_to root_path, alert: "ログインに失敗しました。もう一度お試しください"
  end

  # DELETE /logout
  def destroy
    reset_session
    redirect_to root_path, notice: "ログアウトしました"
  end
end
