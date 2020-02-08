require 'httparty'

# :first_in sets how long it takes before the job is first run. In this case, it is run immediately
SCHEDULER.every '1s', :first_in => 0 do |job|
  # Augenblickverbrauch
  uuid_grid_supply = 'c6ada300-4a00-11ea-99d0-7577b1612d91'
  # Augenblickeinspeisung
  uuid_grid_feet = 'aface870-4a00-11ea-aa3c-8f09c95f5b9c'

  url_overview = 'http://192.168.178.102:8081/'
  response = HTTParty.get(url_overview)

  grid_supply = find_current_grid_watts(uuid_grid_supply, response.parsed_response['data'])
  grid_feed = find_current_grid_watts(uuid_grid_feet, response.parsed_response['data'])
  solar_production = current_solar_production()
  current_consupmtion = current_consumption(solar_production, grid_supply, grid_feed)

  send_event('wattmeter_grid_supply',   { value: grid_supply })
  send_event('wattmeter_grid_feed',   { value: grid_feed })
  send_event('wattmeter_house_power_consumption',   { value: current_consupmtion })
end

def current_consumption(solar_production, grid_supply, grid_feed)
  return solar_production + grid_supply - grid_feed
end

def find_current_grid_watts(uuid, data)
 current_grid_watts = 0
 data.each do |value|
   if value['uuid'] == uuid
     current_grid_watts = value['tuples'][0].last()
     break
   end
 end
 return current_grid_watts * 1000
end

def current_solar_production()
  url_sma = 'https://192.168.178.98/dyn/getDashValues.json'
  response = HTTParty.post(url_sma, :verify => false)
  current_watts = response.parsed_response['result']['017A-B339126F']['6100_40263F00']['1'][0]['val']

  if current_watts.nil? || current_watts == 0
    current_watts = 0.0
  end

  return current_watts
end
