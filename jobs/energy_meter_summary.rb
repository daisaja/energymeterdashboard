require_relative 'meter_helper/grid_meter_client'
require_relative 'meter_helper/solar_meter_client'
require_relative 'meter_helper/heating_meter_client'

if defined?(SCHEDULER)
  SCHEDULER.every '3s', :overlap => false do
    grid_measurements = GridMeasurements.new()
    solar_measurements = SolarMeasurements.new()
    heating_measurements = HeatingMeasurements.new()

    grid_meter_values = {
      'grid_supply_per_month' => {label: 'Netzbezug (Monat)' , value: format_meter_value(grid_measurements.grid_supply_per_month, 'kWh', 1)},
      'grid_feed_per_month' => {label: 'Einspeisung (Monat)' , value: format_meter_value(grid_measurements.grid_feed_per_month, 'kWh', 1)},
      'heating_per_month' => {label: 'Heizung (Monat)' , value: format_meter_value(heating_measurements.heating_per_month, 'kWh', 1)},
      'energy_consumption_per_month' => {label: 'Verbrauch (Monat)' , value: format_meter_value(grid_measurements.energy_consumption_per_month, 'kWh', 1)}, # not implemented yet
      'grid_supply_total' => {label: 'Bezug (Jahr)' , value: format_meter_value(grid_measurements.grid_supply_total, 'kWh', 0)},
      'grid_feed_total' => {label: 'Einspeisung (Jahr)' , value: format_meter_value(grid_measurements.grid_feed_total, 'kWh', 0)},
      # Client liefert kW, Solar liefert W → für einheitliche Anzeige alles in W
      'grid_supply_current' => {label: 'Bezug (jetzt)' , value: format_meter_value(grid_measurements.grid_supply_current * 1000, 'W', 0)},
      'grid_feed_current' => {label: 'Einspeisung (jetzt)' , value: format_meter_value(grid_measurements.grid_feed_current * 1000, 'W', 0)},
      'solar_production_current' => {label: 'Solar (jetzt)' , value: format_meter_value(solar_measurements.solar_watts_current, 'W', 0)}
    }

    send_event('grid_meter_values', { items: grid_meter_values.values })
  end
end

# Formatiert einen Rohwert für die Anzeige im List-Widget, z.B. "2241,2 kWh".
# Rundet nur für die Anzeige – die Meter-Clients liefern weiterhin volle Präzision
# (wichtig für Delta-Berechnungen und InfluxDB).
#
# value:    Numeric (Float oder Integer, kann auch nil sein, falls ein Client ausfällt)
# unit:     'kWh' oder 'W'
# decimals: Nachkommastellen (Zählerstände 0, Monatswerte 1, Leistung 0)
# Rückgabe: String mit gerundetem Wert, deutschem Dezimalkomma und Einheit
def format_meter_value(value, unit, decimals)
  return "– #{unit}" if value.nil?

  number = format("%.#{decimals}f", value.to_f.round(decimals))
  "#{number.tr('.', ',')} #{unit}"
end
