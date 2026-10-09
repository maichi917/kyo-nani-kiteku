module Weather
  # 外部 API の呼び出しに失敗したとき（タイムアウト、HTTP エラー、不正なレスポンスなど）
  class Error < StandardError; end
end
