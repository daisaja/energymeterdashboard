require 'httparty'
require_relative 'grid_meter_client'

# Fragt die Volkszähler-Middleware, wann zuletzt Daten vom vzlogger angekommen sind.
# Nur lesend (GET). Hinweis: Bei leerem Zeitfenster kann die API ein Nachbar-Tupel
# außerhalb des Fensters liefern – daher wird immer der Tupel-Zeitstempel selbst ausgewertet.
class VzMiddlewareClient
  MIDDLEWARE_URL = "http://#{GRID_METER_HOST}/middleware.php"
  WINDOW_SECONDS = 3600
  TIMEOUT_SECONDS = 5

  # Liefert die Zeit des neuesten Tupels (Time) oder nil bei Fehler/keinen Daten.
  def self.last_tuple_time(now = Time.now, uuid = UUID_GRID_SUPPLY_TOTAL)
    from_ms = (now.to_i - WINDOW_SECONDS) * 1000
    to_ms   = now.to_i * 1000
    response = HTTParty.get("#{MIDDLEWARE_URL}/data/#{uuid}.json",
                            query: { from: from_ms, to: to_ms }, timeout: TIMEOUT_SECONDS)
    return nil unless response.code == 200

    tuples = response.parsed_response.dig('data', 'tuples')
    return nil if tuples.nil? || tuples.empty?

    Time.at(tuples.map(&:first).max / 1000.0)
  rescue => e
    puts "[VzMiddleware] Fehler: #{e.message}"
    nil
  end
end
