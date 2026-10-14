# 毎朝6:32（config/recurring.yml）に、マイエリアを設定している全員の今日のアドバイスを準備しておく。
# 7:00 の通知（MorningNotificationJob）は、ここで保存したアドバイスを使うので、天気や AI が混んでいても送れる
class PrepareMorningAdvicesJob < ApplicationJob
  # 天気が取れなかった人や、AI のひとことがない人が残っている
  class NotReady < StandardError; end

  queue_as :default

  # 少し待って、ジョブごとやり直す（待ち時間はだんだん長くなる。全部で5回まで）。
  # 準備できた人は保存したアドバイスを使い回すので、やり直しのときは API を呼ばない。
  # 5回やってもだめなら、あきらめる（7:00 の通知が、その場で作るか、ひとことなしで送る）
  retry_on NotReady, wait: :polynomially_longer, attempts: 5 do |_job, error|
    Rails.logger.error("[PrepareMorningAdvicesJob] 準備をあきらめました: #{error.message}")
  end

  def perform
    not_ready = 0
    User.joins(:location).includes(:location).find_each do |user|
      advice = DailyAdvice.for_today(user)
      not_ready += 1 unless advice.fill_missing_comments!
    rescue Weather::Error => e
      not_ready += 1
      Rails.logger.warn("[PrepareMorningAdvicesJob] user_id=#{user.id} の天気を取れませんでした: #{e.class}: #{e.message}")
    end

    raise NotReady, "#{not_ready}人分の準備ができていません" if not_ready.positive?

    Rails.logger.info("[PrepareMorningAdvicesJob] 全員分の準備ができました")
  end
end
