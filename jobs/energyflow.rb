require_relative 'meter_helper/grid_meter_client'
require_relative 'meter_helper/solar_meter_client'
require_relative 'meter_helper/opendtu_meter_client'
require_relative 'meter_helper/powerwall_client'
require_relative 'meter_helper/heating_meter_client'

if defined?(SCHEDULER)
  SCHEDULER.every '3s', :first_in => 0 do |job|
    begin
      grid      = GridMeasurements.new
      solar     = SolarMeasurements.new
      opendtu   = OpenDTUMeterClient.new
      powerwall = PowerwallClient.new
      heating   = HeatingMeasurements.new

      # Combine SMA inverter + OpenDTU (same pattern as solar_watts.rb)
      combined_solar = OpenStruct.new(
        solar_watts_current: solar.solar_watts_current + opendtu.power_watts
      )

      payload = build_energyflow_payload(grid, combined_solar, powerwall, heating)
      send_event('energyflow', payload)
    rescue => e
      puts "[EnergyFlow] Error: #{e.message}"
    end
  end
end

# Extracted for testability — takes duck-typed client objects
def build_energyflow_payload(grid, solar, powerwall, heating)
  solar_w       = solar.solar_watts_current.to_f
  grid_supply_w = (grid.grid_supply_current * 1000).round(0)
  grid_feed_w   = (grid.grid_feed_current * 1000).round(0)
  battery_w     = powerwall.power_watts.to_f
  heatpump_w    = heating.heating_watts_current.to_f

  # positive = Bezug (supply from grid), negative = Einspeisung (feed into grid)
  grid_w = grid_supply_w - grid_feed_w

  # Battery: positive = charging, negative = discharging
  # Discharge adds to available power (makes house consumption appear higher)
  battery_discharge = [-battery_w, 0].max
  house_w = solar_w + grid_supply_w - grid_feed_w + battery_discharge

  {
    solar_w:     solar_w.round(0),
    grid_w:      grid_w,
    battery_w:   battery_w.round(0),
    battery_soc: powerwall.soc_percent,
    house_w:     house_w.round(0),
    heatpump_w:  heatpump_w.round(0)
  }
end
