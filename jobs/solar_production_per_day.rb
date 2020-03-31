require 'date'

# :first_in sets how long it takes before the job is first run. In this case, it is run immediately
#SCHEDULER.every '1m', :first_in => 0 do |job|
SCHEDULER.every '1m', :first_in => 0 do |job|
  url_sma = 'https://192.168.178.98/dyn/getDashLogger.json'
  response = HTTParty.post(url_sma, :verify => false)

  # rolling 24h window also including values from last day ...
  watts_per_time_unit = response.parsed_response['result']['017A-B339126F']['7000']['1']
  kwh_current_day = kwh_current_day(watts_per_time_unit)

  # two values from json
  watts_per_time_unit = response.parsed_response['result']['017A-B339126F']['7020']['1']
  kwh_last_day = kwh_last_day(watts_per_time_unit)
  #puts "last: #{kwh_last_day}"

  send_event('wattmetersolar_sum', { current: kwh_current_day, last: kwh_last_day})
end

def kwh_current_day(watts_per_time_unit)
  # current seconds of the day
  today_seconds = 0
  t = Time.now
  today = Time.new(t.year, t.month, t.day)
  today_seconds = today.strftime('%s').to_i  # get milliseconds for the day starting from 00:00:00

  # get first data set for current date in seconds
  first_watts_value = 0
  watts_per_time_unit.each do |value|
    # find first data of the day by seconds since 1970
    if value['t'].to_i >= today_seconds
      first_watts_value = value['v'].to_i
      break
    end
  end

  #puts first_watts_value
  last_watts_value = watts_per_time_unit.last['v']
  #puts last_watts_value
  return ((last_watts_value - first_watts_value).to_f / 1000).round(1)
end

# Get produced solar watts from last day
def kwh_last_day(watts_per_time_unit)
  last_watts_value = watts_per_time_unit.last['v'] # since summer time switch it are last day produced watts
  first_watts_value = watts_per_time_unit.first['v'] # since summer time switch it is null ...
  return ((last_watts_value - check_for_null_replace_with_zero(first_watts_value)).to_f / 1000).round(1)
end

# After switch to summer time one array value is null in the morning (looks like a bug in SMA software) Here is the workaround.
def check_for_null_replace_with_zero(value)
  if value == nil
    value = 0
  end
end
