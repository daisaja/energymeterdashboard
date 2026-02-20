require_relative 'meter_helper/grid_meter_client'
require_relative 'meter_helper/solar_meter_client'

# :first_in sets how long it takes before the job is first run. In this case, it is run immediately
SCHEDULER.every '2s', :first_in => 0 do |job|
  grid_measurements = GridMeasurements.new()
  solar_measurements = SolarMeasurements.new()

  grid_supply_current = (grid_measurements.grid_supply_current * 1000).round(0)
  grid_feed_current = (grid_measurements.grid_feed_current * 1000).round(0)

  solar_watts_current = solar_measurements.solar_watts_current
  current_consumption = current_consumption(solar_watts_current, grid_supply_current, grid_feed_current)

  send_event('wattmeter_grid_supply', { value: grid_supply_current })
  send_event('wattmeter_grid_feed', { value: grid_feed_current })
  send_event('wattmeter_house_power_consumption',   { value: current_consumption })
  report_grid(grid_supply_current, grid_feed_current, current_consumption)
end

def current_consumption(solar_production, grid_supply, grid_feed)
  return solar_production + grid_supply - grid_feed
end

def report_grid(grid_supply_current, grid_feed_current, current_consumption)
  reporter = InfluxExporter.new()
  hash = {
           name: 'wattmeter_grid',
           tags: {meter_type: 'grid'},
           fields: {wattmeter_grid_supply: grid_supply_current, wattmeter_grid_feed: grid_feed_current, wattmeter_house_power_consumption: current_consumption.to_i},
         }
  reporter.send_data(hash)
end
