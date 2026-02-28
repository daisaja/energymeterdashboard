require 'httparty'

UUID_GRID_SUPPLY_CURRENT = '2c58c270-0e65-11f1-8833-19d9403165de' # OBIS: 1-0:16.7.0 Momentanleistung (W, signed) - positiv=Bezug, negativ=Einspeisung
UUID_GRID_FEED_TOTAL = '11755f30-0e65-11f1-a7d4-cfd94d2fa168' # OBIS: 1-0:2.8.0 Einspeisung gesamt (Wh)
UUID_GRID_SUPPLY_TOTAL = 'e52fc000-0e64-11f1-b37f-4db1c53870b5' # OBIS: 1-0:1.8.0 Bezug gesamt (Wh)

GRID_METER_HOST = ENV["GRID_METER_HOST"]

VZ_LOGGER_URL = "http://#{GRID_METER_HOST}:8081/"

class GridMeasurements
  @@last_values = {}

  attr_reader :grid_feed_total, :grid_feed_per_month, :grid_feed_current,
  :grid_supply_total, :grid_supply_per_month, :grid_supply_current,
  :energy_consumption_per_month

  def initialize
    fetch_data_from_grid_meter
  end

  def to_s()
    super +
    " grid_feed_total: #{grid_feed_total}
    grid_feed_per_month: #{grid_feed_per_month}
    grid_feed_current: #{grid_feed_current}
    grid_supply_total: #{grid_supply_total}
    grid_supply_per_month: #{grid_supply_per_month}
    grid_supply_current: #{grid_supply_current}
    energy_consumption_per_month: #{energy_consumption_per_month}"
  end

  def fetch_data_from_grid_meter
    response = HTTParty.get(VZ_LOGGER_URL)
    data = response.parsed_response['data']

    # Zählerstände: E320 liefert Wh via SML → in kWh umrechnen
    @grid_supply_total = find_current_grid_value(UUID_GRID_SUPPLY_TOTAL, data) / 1000.0
    @grid_feed_total   = find_current_grid_value(UUID_GRID_FEED_TOTAL, data) / 1000.0

    # Momentanleistung: 16.7.0 liefert W vorzeichenbehaftet → in kW aufteilen
    raw_power_w = find_current_grid_value(UUID_GRID_SUPPLY_CURRENT, data)
    @grid_supply_current = raw_power_w > 0 ? (raw_power_w / 1000.0) : 0.0
    @grid_feed_current   = raw_power_w < 0 ? (raw_power_w.abs / 1000.0) : 0.0

    # Perioden-Register nicht verfügbar am E320 via SML
    @grid_supply_per_month = 0.0
    @grid_feed_per_month   = 0.0
    @energy_consumption_per_month = 0.0

    save_values
  rescue Errno::EHOSTUNREACH, Errno::ECONNREFUSED => e
    puts "[GridMeter] Verbindung zu #{GRID_METER_HOST}:8081 fehlgeschlagen: Gerät nicht erreichbar" unless @@last_values.empty?
    restore_last_values
  end

  def save_values
    @@last_values = {
      grid_feed_total: @grid_feed_total,
      grid_feed_per_month: @grid_feed_per_month,
      grid_feed_current: @grid_feed_current,
      grid_supply_total: @grid_supply_total,
      grid_supply_per_month: @grid_supply_per_month,
      grid_supply_current: @grid_supply_current,
      energy_consumption_per_month: @energy_consumption_per_month
    }
  end

  def restore_last_values
    @grid_feed_total = @@last_values[:grid_feed_total] || 0.0
    @grid_feed_per_month = @@last_values[:grid_feed_per_month] || 0.0
    @grid_feed_current = @@last_values[:grid_feed_current] || 0.0
    @grid_supply_total = @@last_values[:grid_supply_total] || 0.0
    @grid_supply_per_month = @@last_values[:grid_supply_per_month] || 0.0
    @grid_supply_current = @@last_values[:grid_supply_current] || 0.0
    @energy_consumption_per_month = @@last_values[:energy_consumption_per_month] || 0.0
  end
end

def find_current_grid_value(uuid, data)
  data.each do |value|
    if value['uuid'] == uuid
      tuples = value['tuples']
      return tuples[0].last() if tuples && !tuples.empty?
    end
  end
  return 0
end

def is_new_day(now = Time.now)
  midnight = Time.new(now.year, now.month, now.day)
  now > midnight && now < midnight + 600
end

def is_new_month(now = Time.now)
  first_of_month = Time.new(now.year, now.month, 1)
  now > first_of_month && now < first_of_month + 600
end
