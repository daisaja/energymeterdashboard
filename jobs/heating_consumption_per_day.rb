require_relative 'meter_helper/heating_meter_client'

# Todo: Extract to heating meter client

# :first_in sets how long it takes before the job is first run. In this case, it is run immediately
SCHEDULER.every '1m', :first_in => 0 do |job|
  heating_measurements = HeatingMeasurements.new()
  # Verbrauch aktueller Tag
  kwh_current_day = heating_measurements.heating_kwh_current_day
  # Verbrauch gestriger Tag
  kwh_last_day = heating_measurements.heating_kwh_last_day
  send_event('wattmeterheating_sum',   { current: kwh_current_day, last: kwh_last_day })
end
