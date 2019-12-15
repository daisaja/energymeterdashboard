require 'httparty'

# :first_in sets how long it takes before the job is first run. In this case, it is run immediately
SCHEDULER.every '2s', :first_in => 0 do |job|

  # Augenblickverbrauch
  url_overview = 'http://192.168.178.10/a?f=j'
  response = HTTParty.get(url_overview)
  send_event('wattmeterheating',   { value: response.parsed_response['pwr'] })

  # Verbrauch aktueller Tag
  url_day_count = 'http://192.168.178.10/V?d=0&f=j'
  response_day_counts = HTTParty.get(url_day_count)
  array = response_day_counts.parsed_response['val']
  day_sum = 0
  array.each { |a|
    day_sum += a.to_i
  }
  kwh_day = (day_sum/1000)

  # Verbrauch gestriger Tag
  url_last_day_count = 'http://192.168.178.10/V?d=1&f=j'
  response_last_day_counts = HTTParty.get(url_last_day_count)
  array = response_last_day_counts.parsed_response['val']
  last_day_sum = 0
  array.each { |a|
    last_day_sum += a.to_i
  }
  kwh_last_day = (last_day_sum/1000)

  send_event('wattmeterheating_sum',   { current: kwh_day, last: kwh_last_day })

end
