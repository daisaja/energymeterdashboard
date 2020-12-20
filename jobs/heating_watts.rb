require_relative 'meter_helper/heating_meter_client'

SCHEDULER.every '2s', :first_in => 0 do |job|
  heating_measurements = HeatingMeasurements.new()
  send_event('wattmeterheating',   { value: heating_measurements.heating_watts_current})
end
