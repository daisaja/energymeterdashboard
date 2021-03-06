require_relative 'meter_helper/grid_meter_client'
require_relative 'meter_helper/heating_meter_client'

SCHEDULER.every '3s' do
  grid_measurements = GridMeasurements.new()
  solar_measurements = SolarMeasurements.new()
  heating_measurements = HeatingMeasurements.new()

  grid_meter_values = {
    'grid_supply_per_month' => {label: 'Netzbezug (Monat)' , value: grid_measurements.grid_supply_per_month},
    'grid_feed_per_month' => {label: 'Einspeisung (Monat)' , value: grid_measurements.grid_feed_per_month},
    'heating_per_month' => {label: 'Heizung (Monat)' , value: heating_measurements.heating_per_month},
    'energy_consumption_per_month' => {label: 'Verbrauch (Monat)' , value: grid_measurements.energy_consumption_per_month}, # not implemented yet
    'grid_supply_total' => {label: 'Bezug (Jahr)' , value: grid_measurements.grid_supply_total},
    'grid_feed_total' => {label: 'Einspeisung (Jahr)' , value: grid_measurements.grid_feed_total},
    'grid_supply_current' => {label: 'Bezug (jetzt)' , value: grid_measurements.grid_supply_current},
    'grid_feed_current' => {label: 'Einspeisung (jetzt)' , value: grid_measurements.grid_feed_current},
    'solar_production_current' => {label: 'Solar (jetzt)' , value: solar_measurements.solar_watts_current}
  }

  send_event('grid_meter_values', { items: grid_meter_values.values })
end
