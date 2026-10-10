# 毎朝7時（config/recurring.yml）に、マイエリアを設定している全員へ LINE で通知を送る
class MorningNotificationJob < ApplicationJob
  queue_as :default

  def perform
    sent = 0
    failed = 0

    User.joins(:location).includes(:location).find_each do |user|
      Line::Messaging.push_text(to: user.line_user_id, text: MorningMessage.for(user))
      sent += 1
    rescue Weather::Error, Line::Messaging::Error => e
      # 1人に送れなくても、止めずに次の人へ。理由はログに残す
      failed += 1
      Rails.logger.error("[MorningNotificationJob] user_id=#{user.id} の通知に失敗しました: #{e.class}: #{e.message}")
    end

    Rails.logger.info("[MorningNotificationJob] 送信 #{sent}件 / 失敗 #{failed}件")
  end
end
