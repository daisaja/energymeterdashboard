require 'httparty'

class OpenDTUMeterClient

  attr_reader :power_watts, :yield_day, :yield_total

  def initialize
    @opendtu_host = ENV['OPENDTU_HOST']
    @opendtu_url = "http://#{@opendtu_host}:80/api/livedata/status"
    fetch_data_from_opendtu()
  end

  def fetch_data_from_opendtu
    begin
      response = HTTParty.get(@opendtu_url)

      @power_watts = response.parsed_response['total']['Power']['v'].to_f
      @yield_day = response.parsed_response['total']['YieldDay']['v'].to_f
      @yield_total = response.parsed_response['total']['YieldTotal']['v'].to_f
    rescue => e
      puts "Error while retrieving OpenDTU data: #{e.message}"
      @power_watts = 0.0
      @yield_day = 0.0
      @yield_total = 0.0
    end
  end 

  def to_s()
    super +
    " power_watts: #{power_watts}
    yield_day: #{yield_day}
    yield_total: #{yield_total}"
  end
end

