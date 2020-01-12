require 'httparty'

# :first_in sets how long it takes before the job is first run. In this case, it is run immediately
SCHEDULER.every '1m', :first_in => 0 do |job|
  # Verbrauch aktueller Tag
  url_current_day_count = 'http://192.168.178.10/V?d=0&f=j'
  kwh_current_day = calculate_sum_of_watts(url_current_day_count)

  # Verbrauch gestriger Tag
  url_last_day_count = 'http://192.168.178.10/V?d=1&f=j'
  kwh_last_day = calculate_sum_of_watts(url_last_day_count)
  send_event('wattmeternet_sum',   { current: kwh_current_day, last: kwh_last_day })
end

def calculate_sum_of_watts(data_url_to_fetch_from)
  response_with_data = HTTParty.get(data_url_to_fetch_from)
  array = response_with_data.parsed_response['val']
  last_day_sum = 0
  array.each { |a|
    last_day_sum += a.to_i
  }
  return (last_day_sum.to_f/1000).round(1)
end