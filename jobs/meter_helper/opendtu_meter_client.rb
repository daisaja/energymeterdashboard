require 'httparty'

class OpenDTUMeterClient
  @@last_values = {}

  attr_reader :power_watts, :yield_day, :yield_total

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
    save_values
  rescue Errno::EHOSTUNREACH, Errno::ECONNREFUSED => e
    puts "[OpenDTU] Verbindung zu #{@opendtu_host} fehlgeschlagen: Gerät nicht erreichbar" unless @@last_values.empty?
    restore_last_values
  rescue => e
    puts "[OpenDTU] Fehler: #{e.message}" unless @@last_values.empty?
    restore_last_values
  end

  def save_values
    @@last_values = {
      power_watts: @power_watts,
      yield_day: @yield_day,
      yield_total: @yield_total
    }
  end

  def restore_last_values
    @power_watts = @@last_values[:power_watts] || 0.0
    @yield_day = @@last_values[:yield_day] || 0.0
    @yield_total = @@last_values[:yield_total] || 0.0
  end 

  def to_s()
    super +
    " power_watts: #{power_watts}
    yield_day: #{yield_day}
    yield_total: #{yield_total}"
  end
end

