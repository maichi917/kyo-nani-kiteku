require "net/http"

module Weather
  # APIと話す窓口。URLに問い合わせて、JSONをRubyのデータ（配列やハッシュ）に変換して返す。失敗したら Weather::Error を投げる
  module HttpClient
    TIMEOUT_SECONDS = 5

    def self.get_json(endpoint, params)
      uri = URI(endpoint)
      uri.query = URI.encode_www_form(params)

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                 open_timeout: TIMEOUT_SECONDS, read_timeout: TIMEOUT_SECONDS) do |http|
        http.get(uri.request_uri)
      end
      raise Error, "HTTP #{response.code} (#{uri.host})" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    rescue Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError, JSON::ParserError => e
      raise Error, "#{e.class}: #{e.message} (#{uri.host})"
    end
  end
end
