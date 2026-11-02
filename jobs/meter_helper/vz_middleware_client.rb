require 'httparty'
require_relative 'grid_meter_client'

# Fragt die Volkszähler-Middleware, wann zuletzt Daten vom vzlogger angekommen sind.
# Nur lesend (GET). Hinweis: Bei leerem Zeitfenster kann die API ein Nachbar-Tupel
# außerhalb des Fensters liefern – daher wird immer der Tupel-Zeitstempel selbst ausgewertet.
class VzMiddlewareClient
  MIDDLEWARE_URL = "http://#{GRID_METER_HOST}/middleware.php"
  WINDOW_SECONDS = 3600
  TIMEOUT_SECONDS = 5

  # Liefert eines von:
  #   Time      – Zeitpunkt des neuesten Tupels
  #   :empty    – gültige Antwort ohne Tupel
  #   :db_error – Middleware antwortet, meldet aber einen Datenbankfehler (SQLSTATE)
  #   :error    – nicht erreichbar, HTTP-Fehler, sonstiger Exception-Body oder ungültige Antwort
  def self.fetch(now = Time.now, uuid = UUID_GRID_SUPPLY_TOTAL)
    from_ms = (now.to_i - WINDOW_SECONDS) * 1000
    to_ms   = now.to_i * 1000
    response = HTTParty.get("#{MIDDLEWARE_URL}/data/#{uuid}.json",
                            query: { from: from_ms, to: to_ms }, timeout: TIMEOUT_SECONDS)
    body = response.parsed_response
    return :error unless body.is_a?(Hash)

    # Exception-Body vor dem Status-Code auswerten: die Middleware meldet DB-Fehler mit HTTP 400
    if body.key?('exception')
      message = body['exception'].is_a?(Hash) ? body['exception']['message'].to_s : body['exception'].to_s
      return message.include?('SQLSTATE') ? :db_error : :error
    end

    return :error unless response.code == 200

    tuples = body.dig('data', 'tuples')
    return :empty if tuples.nil? || tuples.empty?

    Time.at(tuples.map(&:first).max / 1000.0)
  rescue => e
    puts "[VzMiddleware] Fehler: #{e.message}"
    :error
  end

  # Wie fetch, aber nur die Zeit (Time) oder nil bei Fehler/keinen Daten.
  def self.last_tuple_time(now = Time.now, uuid = UUID_GRID_SUPPLY_TOTAL)
    result = fetch(now, uuid)
    result.is_a?(Time) ? result : nil
  end
end
