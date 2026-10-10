require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module KyoNaniKiteku
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.time_zone = "Tokyo"

    # LINE 公式アカウントの友だち追加リンク
    config.x.line_friend_url = "https://line.me/R/ti/p/@134ddgvb"
    # 本番のアプリの URL（LINE の通知文の最後に入れる）
    config.x.app_url = "https://kyo-nani-kiteku.onrender.com/"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
