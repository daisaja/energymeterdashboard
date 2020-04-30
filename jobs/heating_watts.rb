require_relative 'meter_helper/heating_meter_client'

SCHEDULER.every '2s', :first_in => 0 do |job|
  heating_measurements = fetch_data_from_heating_meter()
  send_event('wattmeterheating',   { value: heating_measurements.heating_watts_current})
end
