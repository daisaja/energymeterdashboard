require 'httparty'


SOLAR_METER_HOST = ENV['SOLAR_METER_HOST']
SMA_VALUES_URL = "https://#{SOLAR_METER_HOST}/dyn/getDashValues.json"
SMA_LOGGER_URL = "https://#{SOLAR_METER_HOST}/dyn/getDashLogger.json"

class SolarMeasurements
  @@last_values = {}

  attr_reader :solar_watts_current, :solar_watts_per_month

  def initialize
    fetch_data_from_solar_meter()
  end

  def to_s()
    super +
    " solar_watts_current: #{solar_watts_current}
    solar_watts_per_month: #{solar_watts_per_month}"
  end

  def fetch_data_from_solar_meter
    response = HTTParty.post(SMA_VALUES_URL, verify: false) #without ssl check

    begin
      @solar_watts_current = response.parsed_response['result']['017A-B339126F']['6100_40263F00']['1'][0]['val']
    rescue
      begin
        @solar_watts_current = response.parsed_response['result']['017A-xxxxx26F']['6100_40263F00']['1'][0]['val']
      rescue
        puts '[SolarMeter] Konnte Wert nicht aus Antwort lesen'
        @solar_watts_current = -1
      end
    end

    if @solar_watts_current.nil? || @solar_watts_current == 0
      @solar_watts_current = 0.0
    end
    @solar_watts_per_month = 0.0 # not implemented yet
    save_values
  rescue Errno::EHOSTUNREACH, Errno::ECONNREFUSED => e
    puts "[SolarMeter] Verbindung zu #{SOLAR_METER_HOST} fehlgeschlagen: Gerät nicht erreichbar"
    restore_last_values
  end

  def save_values
    @@last_values = {
      solar_watts_current: @solar_watts_current,
      solar_watts_per_month: @solar_watts_per_month
    }
  end

  def restore_last_values
    @solar_watts_current = @@last_values[:solar_watts_current] || 0.0
    @solar_watts_per_month = @@last_values[:solar_watts_per_month] || 0.0
  end
end
