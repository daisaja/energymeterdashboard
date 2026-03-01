require 'httparty'

HEATING_METER_HOST = ENV['HEATING_METER_HOST']

YOULESS_VALUES_URL = "http://#{HEATING_METER_HOST}/a?f=j"
YOULESS_MONTHS_URL = "http://#{HEATING_METER_HOST}/V?m=%{month}&?f=j"
YOULESS_CURRENT_DAY_KWH = "http://#{HEATING_METER_HOST}/V?d=0&f=j"
YOULESS_LAST_DAY_KWH = "http://#{HEATING_METER_HOST}/V?d=1&f=j"

class HeatingMeasurements
  @@last_values = {}

  attr_reader :heating_watts_current, :heating_per_month, :heating_kwh_current_day, :heating_kwh_last_day

  def initialize
    fetch_data_from_heating_meter()
  end

  def to_s()
    super +
    " heating_watts_current: #{heating_watts_current}
    heating_per_month: #{heating_per_month}
    heating_kwh_current_day: #{heating_kwh_current_day}
    heating_kwh_last_day: #{heating_kwh_last_day}"
  end

  def fetch_data_from_heating_meter
    response = HTTParty.get(YOULESS_VALUES_URL)
    @heating_watts_current = response.parsed_response['pwr']

    begin
      response = HTTParty.get(YOULESS_MONTHS_URL % {month: Date.today.month})
      @heating_per_month = 0.0
      response['val'].each do |value|
        @heating_per_month += value.to_f
      end

      response = HTTParty.get(YOULESS_CURRENT_DAY_KWH)
      @heating_kwh_current_day = calculate_sum_of_watts(response)

      response = HTTParty.get(YOULESS_LAST_DAY_KWH)
      @heating_kwh_last_day = calculate_sum_of_watts(response)
    rescue StandardError => e
      puts "[HeatingMeter] Sekundärdaten nicht verfügbar: #{e.message}"
      @heating_per_month = @@last_values[:heating_per_month] || 0.0
      @heating_kwh_current_day = @@last_values[:heating_kwh_current_day] || 0.0
      @heating_kwh_last_day = @@last_values[:heating_kwh_last_day] || 0.0
    end

    save_values
  rescue StandardError => e
    puts "[HeatingMeter] Verbindung zu #{HEATING_METER_HOST} fehlgeschlagen: #{e.message}"
    restore_last_values
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

  def calculate_sum_of_watts(response_with_data)
    array = response_with_data.parsed_response['val']
    last_day_sum = 0
    array.each { |a|
      last_day_sum += a.to_i
    }
    return (last_day_sum / 1000.0).round(1)
  end
end
