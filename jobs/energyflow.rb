require 'ostruct'

if defined?(SCHEDULER)
  # Reads live values from globals set by individual jobs (grid_watts, solar_watts,
  # heating_watts, powerwall) — no own HTTP calls to avoid duplicate connections
  # and race conditions on shared class state (@@last_values, @@auth_token).
  SCHEDULER.every '3s', :first_in => 0, :overlap => false do |job|
    grid      = OpenStruct.new(
      grid_supply_current: defined?($grid_supply_kw)          ? $grid_supply_kw.to_f          : 0.0,
      grid_feed_current:   defined?($grid_feed_kw)            ? $grid_feed_kw.to_f            : 0.0
    )
    solar     = OpenStruct.new(
      solar_watts_current: defined?($solar_watts_combined)    ? $solar_watts_combined.to_f    : 0.0
    )
    powerwall = OpenStruct.new(
      power_watts:         defined?($powerwall_battery_power) ? $powerwall_battery_power.to_f : 0.0,
      soc_percent:         defined?($powerwall_soc_percent)   ? $powerwall_soc_percent.to_f   : 0.0
    )
    heating   = OpenStruct.new(
      heating_watts_current: defined?($heating_watts_current) ? $heating_watts_current.to_f   : 0.0
    )

    payload = build_energyflow_payload(grid, solar, powerwall, heating)
    payload[:solar_kwh]    = defined?($solar_kwh_current_day)    ? $solar_kwh_current_day.to_f    : 0.0
    payload[:grid_kwh]     = defined?($kwh_supply_current_day)   ? $kwh_supply_current_day.to_f   : 0.0
    payload[:heatpump_kwh] = defined?($heatpump_kwh_current_day) ? $heatpump_kwh_current_day.to_f : 0.0
    send_event('energyflow', payload)
  rescue => e
    puts "[EnergyFlow] Error: #{e.message}"
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
