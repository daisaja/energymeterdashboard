require 'httparty'
require_relative 'meter_helper/grid_meter_client'

$solar_peak_of_the_day = 0

SCHEDULER.every '2s', :first_in => 0 do |job|
  url_sma = 'https://192.168.178.98/dyn/getDashValues.json'
  response = HTTParty.post(url_sma, :verify => false) #without ssl check
  current_watts = response.parsed_response['result']['017A-B339126F']['6100_40263F00']['1'][0]['val']

  if current_watts.nil? || current_watts == 0
    current_watts = 0.0
  end

  reset_solar_peak_meter()
  set_solar_current_peak(current_watts)

  send_event('wattmetersolar', { value: current_watts })
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
