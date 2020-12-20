require 'httparty'

UUID_GRID_FEED_CURRENT = 'aface870-4a00-11ea-aa3c-8f09c95f5b9c' # OBIS: 255-255::2.7.0*255
UUID_GRID_FEED_TOTAL = 'e564e6e0-4a00-11ea-af71-a55e127a0bfc' # OBIS: 255-255:2.8.0*255
UUID_GRID_FEED_PER_MONTH = '0185bb38-769c-401f-9372-b89d615c9920' # OBIS: 255-255:2.9.0*255
UUID_GRID_SUPPLY_TOTAL = '007aeef0-4a01-11ea-8773-6bda87ed0b9a' # OBIS: 255-255:1.8.0*255
UUID_GRID_SUPPLY_PER_MONTH = '472573b2-a888-4851-ada9-ffd8cd386001' # OBIS: 255-255:1.9.0*255
UUID_GRID_SUPPLY_CURRENT = 'c6ada300-4a00-11ea-99d0-7577b1612d91' # OBIS: 255-255:1.7.0*255

GRID_METER_HOST = ENV['GRID_METER_HOST']

VZ_LOGGER_URL = "http://" + GRID_METER_HOST + ":8081/"

class GridMeasurements
  attr_reader :grid_feed_total, :grid_feed_per_month, :grid_feed_current,
  :grid_supply_total, :grid_supply_per_month, :grid_supply_current,
  :energy_consumption_per_month

  def initialize()
    fetch_data_from_grid_meter()
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

  def fetch_data_from_grid_meter()
    response = HTTParty.get(VZ_LOGGER_URL)
    data = response.parsed_response['data']
    @grid_feed_total = find_current_grid_kwh(UUID_GRID_FEED_TOTAL, data)
    @grid_feed_per_month = find_current_grid_kwh(UUID_GRID_FEED_PER_MONTH, data)
    @grid_feed_current = find_current_grid_kwh(UUID_GRID_FEED_CURRENT, data)
    @grid_supply_total= find_current_grid_kwh(UUID_GRID_SUPPLY_TOTAL, data)
    @grid_supply_per_month = find_current_grid_kwh(UUID_GRID_SUPPLY_PER_MONTH, data)
    @grid_supply_current = find_current_grid_kwh(UUID_GRID_SUPPLY_CURRENT, data)
    @energy_consumption_per_month = 0.0 # not implemented yet
  end
end

def find_current_grid_kwh(uuid, data)
 current_grid_watts = 0
 data.each do |value|
   if value['uuid'] == uuid
     current_grid_watts = value['tuples'][0].last()
     break
   end
 end
 return current_grid_watts
end

def is_new_day()
  now = Time.now
  midnight = Time.new(now.year, now.month, now.day)
  _600s_after_midnight = midnight + 600 # Time window 600s
  if now > midnight and now < _600s_after_midnight
    return true
  else
    return false
  end
end
