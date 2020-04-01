require_relative 'meter_helper/grid_meter_client'
require_relative 'meter_helper/solar_meter_client'

$solar_peak_of_the_day = 0

SCHEDULER.every '2s', :first_in => 0 do |job|
  solar_measurements = fetch_data_from_solar_meter()

  reset_solar_peak_meter()
  set_solar_current_peak(solar_measurements.solar_watts_current)

  send_event('wattmetersolar', { value: solar_measurements.solar_watts_current })
  send_event('solar_peak_meter', { value: $solar_peak_of_the_day })
end

def reset_solar_peak_meter()
  if is_new_day()
    $solar_peak_of_the_day = 0
  end
end

def set_solar_current_peak(current_watts)
  if $solar_peak_of_the_day < current_watts
    $solar_peak_of_the_day = current_watts
  end
end
