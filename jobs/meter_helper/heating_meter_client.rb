require 'httparty'

YOULESS_VALUES_URL = 'http://192.168.178.10/a?f=j'
YOULESS_MONTHS_URL = "http://192.168.178.10/V?m=%{month}&?f=j"

class HeatingMeasurements
  def initialize(heating_watts_current, heating_per_month)
     @heating_watts_current = heating_watts_current
     @heating_per_month = heating_per_month
  end

  attr_reader :heating_watts_current
  attr_reader :heating_per_month

  def to_string()
    puts "heating_watts_current: #{@heating_watts_current}"
    puts "heating_per_month: #{@heating_per_month}"
  end
end

def fetch_data_from_heating_meter()
  response = HTTParty.get(YOULESS_VALUES_URL)
  heating_watts_current = response.parsed_response['pwr']

  response = HTTParty.get(YOULESS_MONTHS_URL % {month: Date.today.month})
  heating_per_month = 0.0
  response['val'].each do |value|
      heating_per_month += value.to_f
  end

  HeatingMeasurements.new(heating_watts_current, heating_per_month)
end
