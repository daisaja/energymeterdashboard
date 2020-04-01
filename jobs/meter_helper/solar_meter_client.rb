require 'httparty'

SMA_URL = 'https://192.168.178.98/dyn/getDashValues.json'

class SolarMeasurements
  def initialize(solar_watts_current)
     @solar_watts_current = solar_watts_current
  end

  attr_reader :solar_watts_current

  def to_string()
    puts "solar_watts_current: #{@solar_watts_current}"
  end
end

def fetch_data_from_solar_meter()
  response = HTTParty.post(SMA_URL, :verify => false) #without ssl check
  solar_watts_current = response.parsed_response['result']['017A-B339126F']['6100_40263F00']['1'][0]['val']

  if solar_watts_current.nil? || solar_watts_current == 0
    solar_watts_current = 0.0
  end

  SolarMeasurements.new(solar_watts_current)
end
