require_relative 'meter_helper/heating_meter_client'

# Todo: Extract to heating meter client

# :first_in sets how long it takes before the job is first run. In this case, it is run immediately
SCHEDULER.every '1m', :first_in => 0 do |job|
  heating_measurements = HeatingMeasurements.new()
  # Verbrauch aktueller Tag (nil = veraltete Gerätedaten, bleibt nil)
  $heatpump_kwh_current_day = heating_measurements.heating_kwh_current_day
  # Verbrauch heute/gestern, nil wird als nil gesendet (Widget zeigt –)
  send_event('wattmeterheating_sum', heating_measurements.day_event_payload)
end
