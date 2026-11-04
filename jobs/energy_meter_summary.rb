require_relative 'meter_helper/grid_meter_client'
require_relative 'meter_helper/solar_meter_client'
require_relative 'meter_helper/heating_meter_client'

if defined?(SCHEDULER)
  SCHEDULER.every '3s', :overlap => false do
    items = overview_items(GridMeasurements.new(), SolarMeasurements.new(), HeatingMeasurements.new())
    send_event('grid_meter_values', { items: items })
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

# Baut die Zeilen für das Overview-Widget (Reihenfolge = Anzeige).
# Monats-/Jahreswerte kommen aus grid_consumption_per_month.rb (Globals) und sind
# erst gültig, wenn $month_state_initialized true ist – vorher "– kWh".
def overview_items(grid, solar, heating)
  month_ready = defined?($month_state_initialized) && $month_state_initialized == true

  warning = defined?($vzlogger_warning) ? $vzlogger_warning : nil

  items = [
    {label: 'Netzbezug (Monat)', value: format_meter_value((month_ready && defined?($kwh_supply_current_month) ? $kwh_supply_current_month : nil), 'kWh', 1)},
    {label: 'Einspeisung (Monat)', value: format_meter_value((month_ready && defined?($kwh_feed_current_month) ? $kwh_feed_current_month : nil), 'kWh', 1)},
    {label: 'Heizung (Monat)', value: format_meter_value(heating.heating_per_month, 'kWh', 1)},
    {label: 'Verbrauch (Monat)', value: format_meter_value((month_ready ? $kwh_consumption_current_month : nil), 'kWh', 1)},
    {label: 'Eigenverbrauch (Monat)', value: format_meter_value((month_ready ? $kwh_self_consumption_current_month : nil), 'kWh', 1)},
    {label: 'Eigenverbrauchsquote (Monat)', value: format_meter_value((month_ready ? $self_consumption_ratio_current_month : nil), '%', 0)},
    {label: 'Autarkie (Monat)', value: format_meter_value((month_ready ? $autarky_current_month : nil), '%', 0)},
    {label: 'Bezug (Jahr)', value: format_meter_value((month_ready && defined?($kwh_supply_current_year) ? $kwh_supply_current_year : nil), 'kWh', 0)},
    {label: 'Einspeisung (Jahr)', value: format_meter_value((month_ready && defined?($kwh_feed_current_year) ? $kwh_feed_current_year : nil), 'kWh', 0)},
    {label: 'Zählerstand Bezug', value: format_meter_value(grid.grid_supply_total, 'kWh', 0)},
    {label: 'Zählerstand Einspeisung', value: format_meter_value(grid.grid_feed_total, 'kWh', 0)},
    # Client liefert kW, Solar liefert W → für einheitliche Anzeige alles in W
    {label: 'Bezug (jetzt)', value: format_meter_value(grid.grid_supply_current * 1000, 'W', 0)},
    {label: 'Einspeisung (jetzt)', value: format_meter_value(grid.grid_feed_current * 1000, 'W', 0)},
    {label: 'Solar (jetzt)', value: format_meter_value(solar.solar_watts_current, 'W', 0)}
  ]

  # Warnung aus vzlogger_status.rb (vzlogger ausgefallen) als erste Zeile
  items.unshift({label: '⚠ Warnung', value: warning}) if warning
  items
end
