require 'httparty'

class OpenDTUMeterClient
  @@last_values = {}

  attr_reader :power_watts, :yield_day, :yield_total, :yield_total_kwh

  def initialize
    @opendtu_host = ENV['OPENDTU_HOST']
    @opendtu_url = "http://#{@opendtu_host}:80/api/livedata/status"
    fetch_data_from_opendtu()
  end

  def fetch_data_from_opendtu
    response = HTTParty.get(@opendtu_url)

    @power_watts = response.parsed_response['total']['Power']['v'].to_f.round(0)
    @yield_day = response.parsed_response['total']['YieldDay']['v'].to_f.round(0)
    @yield_total = response.parsed_response['total']['YieldTotal']['v'].to_f.round(0)
    # YieldTotal ist bereits in kWh; fuer Monatsdeltas mit 3 Nachkommastellen, nil wenn <= 0
    total_kwh = response.parsed_response['total']['YieldTotal']['v'].to_f
    @yield_total_kwh = total_kwh > 0 ? total_kwh.round(3) : nil
    save_values
  rescue Errno::EHOSTUNREACH, Errno::ECONNREFUSED => e
    puts "[OpenDTU] Verbindung zu #{@opendtu_host} fehlgeschlagen: Gerät nicht erreichbar"
    restore_last_values
  rescue => e
    puts "[OpenDTU] Fehler: #{e.message}"
    restore_last_values
  end

  def save_values
    @@last_values = {
      power_watts: @power_watts,
      yield_day: @yield_day,
      yield_total: @yield_total,
      yield_total_kwh: @yield_total_kwh
    }
  end

  def restore_last_values
    @power_watts = @@last_values[:power_watts] || 0.0
    @yield_day = @@last_values[:yield_day] || 0.0
    @yield_total = @@last_values[:yield_total] || 0.0
    @yield_total_kwh = @@last_values[:yield_total_kwh]
  end 

  def to_s()
    super +
    " power_watts: #{power_watts}
    yield_day: #{yield_day}
    yield_total: #{yield_total}"
  end
end

