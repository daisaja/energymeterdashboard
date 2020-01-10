# :first_in sets how long it takes before the job is first run. In this case, it is run immediately
#SCHEDULER.every '1m', :first_in => 0 do |job|
SCHEDULER.every '1m', :first_in => 0 do |job|
  url_sma = 'https://192.168.178.98/dyn/getDashLogger.json'
  response = HTTParty.post(url_sma, :verify => false)

  watts_per_time_unit = response.parsed_response['result']['017A-B339126F']['7000']['1']
  kwh_current_day = kwh_per_day(watts_per_time_unit)

  watts_per_time_unit = response.parsed_response['result']['017A-B339126F']['7020']['1']
  kwh_last_day = kwh_per_day(watts_per_time_unit)

  send_event('wattmetersolar_sum', { current: kwh_current_day, last: kwh_last_day})
end

def kwh_per_day(watts_per_time_unit)
  last_watts_value = watts_per_time_unit.last['v']
  first_watts_value = watts_per_time_unit.first['v']
  return ((last_watts_value - first_watts_value).to_f / 1000).round(1)
end
