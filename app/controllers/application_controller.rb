class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # ビューからも current_user と logged_in? を使えるようにする
  helper_method :current_user, :logged_in?

  private

  # 今ログインしているユーザー。ログインしていなければ nil
  def current_user
    return @current_user if defined?(@current_user)

    @current_user = User.find_by(id: session[:user_id])
  end

  def logged_in?
    current_user.present?
  end

  # ログインが必要なページで使う。ログインしていなければトップへ戻す
  def require_login
    return if logged_in?

    redirect_to root_path, alert: "LINE でログインしてください"
  end
end
