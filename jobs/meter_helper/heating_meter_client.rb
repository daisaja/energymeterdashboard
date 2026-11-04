require 'httparty'
require 'date'

HEATING_METER_HOST = ENV['HEATING_METER_HOST']

YOULESS_VALUES_URL = "http://#{HEATING_METER_HOST}/a?f=j"
YOULESS_MONTHS_URL = "http://#{HEATING_METER_HOST}/V?m=%{month}&f=j"
YOULESS_CURRENT_DAY_KWH = "http://#{HEATING_METER_HOST}/V?d=0&f=j"
YOULESS_LAST_DAY_KWH = "http://#{HEATING_METER_HOST}/V?d=1&f=j"

class HeatingMeasurements
  @@last_values = {}

  attr_reader :heating_watts_current, :heating_per_month, :heating_kwh_current_day, :heating_kwh_last_day

  def initialize(today = Date.today)
    fetch_data_from_heating_meter(today)
  end

  def to_s()
    super +
    " heating_watts_current: #{heating_watts_current}
    heating_per_month: #{heating_per_month}
    heating_kwh_current_day: #{heating_kwh_current_day}
    heating_kwh_last_day: #{heating_kwh_last_day}"
  end

  def fetch_data_from_heating_meter(today = Date.today)
    response = HTTParty.get(YOULESS_VALUES_URL)
    @heating_watts_current = response.parsed_response['pwr']

    begin
      # Monat: nur gültig, wenn tm im aktuellen Monat liegt (Gerät hält 12 Monate,
      # m=11 kann also den November des Vorjahres liefern).
      response = HTTParty.get(YOULESS_MONTHS_URL % {month: today.month})
      month_start = youless_tm_date(response)
      if month_start && month_start.year == today.year && month_start.month == today.month
        @heating_per_month = 0.0
        response['val'].each do |value|
          number = parse_youless_number(value)
          @heating_per_month += number if number
        end
      else
        puts "[HeatingMeter] Monatsdaten veraltet (tm=#{response['tm'].inspect}), ignoriert"
        @heating_per_month = nil
      end

      # Tag: d=0 muss heute sein, d=1 gestern – sonst steht die Geräteuhr falsch.
      response = HTTParty.get(YOULESS_CURRENT_DAY_KWH)
      @heating_kwh_current_day = youless_tm_date(response) == today ? calculate_sum_of_watts(response) : nil

      response = HTTParty.get(YOULESS_LAST_DAY_KWH)
      @heating_kwh_last_day = youless_tm_date(response) == today - 1 ? calculate_sum_of_watts(response) : nil
    rescue StandardError => e
      puts "[HeatingMeter] Sekundärdaten nicht verfügbar: #{e.message}"
    end

    save_values
  rescue StandardError => e
    puts "[HeatingMeter] Verbindung zu #{HEATING_METER_HOST} fehlgeschlagen: #{e.message}"
    restore_last_values
  end

  # Payload für das Number-Widget. Veraltete Tageswerte (nil) werden als 0.0
  # gesendet, sonst zeigt das Widget "NaN%".
  def day_event_payload
    { current: heating_kwh_current_day || 0.0, last: heating_kwh_last_day || 0.0 }
  end

  def save_values
    @@last_values = {
      heating_watts_current: @heating_watts_current,
      heating_per_month: @heating_per_month,
      heating_kwh_current_day: @heating_kwh_current_day,
      heating_kwh_last_day: @heating_kwh_last_day
    }
  end

  def restore_last_values
    @heating_watts_current = @@last_values[:heating_watts_current] || 0.0
    @heating_per_month = @@last_values[:heating_per_month] || 0.0
    @heating_kwh_current_day = @@last_values[:heating_kwh_current_day] || 0.0
    @heating_kwh_last_day = @@last_values[:heating_kwh_last_day] || 0.0
  end

  # Startdatum der Periode aus "tm" (z.B. "2026-09-23T00:00:00"), nil wenn ungültig.
  def youless_tm_date(response)
    tm = response.parsed_response['tm']
    Date.iso8601(tm.to_s[0, 10])
  rescue ArgumentError, Date::Error
    nil
  end

  # YouLess liefert Zahlen als String mit führenden Leerzeichen und deutschem
  # Dezimalkomma (z.B. " 8,100"). Gibt Float zurück, nil bei nil/leer.
  def parse_youless_number(value)
    return nil if value.nil?
    return value.to_f if value.is_a?(Numeric)

    str = value.to_s.strip
    return nil if str.empty?

    str.tr(',', '.').to_f
  end

  def calculate_sum_of_watts(response_with_data)
    array = response_with_data.parsed_response['val']
    last_day_sum = 0.0
    array.each { |a|
      number = parse_youless_number(a)
      last_day_sum += number if number
    }
    return (last_day_sum / 1000.0).round(1)
  end
end
