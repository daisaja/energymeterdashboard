require 'httparty'

SMA_VALUES_URL = 'https://192.168.178.98/dyn/getDashValues.json'
SMA_LOGGER_URL = 'https://192.168.178.98/dyn/getDashLogger.json'

class SolarMeasurements
  def initialize(solar_watts_current, solar_watts_per_month)
     @solar_watts_current = solar_watts_current
     @solar_watts_per_month = solar_watts_per_month
  end

  attr_reader :solar_watts_current
  attr_reader :solar_watts_per_month

  def to_string()
    puts "solar_watts_current: #{@solar_watts_current}"
    puts "solar_watts_per_month: #{@solar_watts_per_month}"
  end
end

def fetch_data_from_solar_meter()
  response = HTTParty.post(SMA_VALUES_URL, :verify => false) #without ssl check
  solar_watts_current = response.parsed_response['result']['017A-B339126F']['6100_40263F00']['1'][0]['val']

  if solar_watts_current.nil? || solar_watts_current == 0
    solar_watts_current = 0.0
  end

  solar_watts_per_month = 0.0 # not implemented yet

  SolarMeasurements.new(solar_watts_current, solar_watts_per_month)
end
