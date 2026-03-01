require 'date'

# :first_in sets how long it takes before the job is first run. In this case, it is run immediately
#SCHEDULER.every '1m', :first_in => 0 do |job|
SCHEDULER.every '1m', :first_in => 0 do |job|
  url_sma = "https://#{ENV['SOLAR_METER_HOST']}/dyn/getDashLogger.json" #TODO refactor and extract logic to solar_meter_client
  response = HTTParty.post(url_sma, :verify => false)

  # rolling 24h window also including values from last day ...
  begin  # "try" block
    watts_per_time_unit = response.parsed_response['result']['017A-B339126F']['7000']['1']
  rescue # optionally: `rescue Exception => ex`
      watts_per_time_unit = response.parsed_response['result']['017A-xxxxx26F']['7000']['1']
  end
  kwh_current_day = kwh_current_day(watts_per_time_unit)

  # two values from json
  begin  # "try" block
    watts_per_time_unit = response.parsed_response['result']['017A-B339126F']['7020']['1']
  rescue # optionally: `rescue Exception => ex`
      watts_per_time_unit = response.parsed_response['result']['017A-xxxxx26F']['7020']['1']
  end
  kwh_last_day = kwh_last_day(watts_per_time_unit)
  #puts "last: #{kwh_last_day}"

  send_event('wattmetersolar_sum', { current: kwh_current_day, last: kwh_last_day})
end

def kwh_current_day(watts_per_time_unit)
  # current seconds of the day
  today_seconds = 0
  t = Time.now
  today = Time.new(t.year, t.month, t.day)
  today_seconds = today.to_i  # get seconds for the day starting from 00:00:00

  # get first data set for current date in seconds
  first_watts_value = 0
  watts_per_time_unit.each do |value|
    # find first data of the day by seconds since 1970
    if value['t'].to_i >= today_seconds
      first_watts_value = value['v'].to_i
      break
    end
  end

  last_watts_value = watts_per_time_unit.last['v']

  return ((last_watts_value - first_watts_value).to_f / 1000).round(1)
end

# Get produced solar watts from last day
def kwh_last_day(watts_per_time_unit)
  first_watts_value = watts_per_time_unit.first['v'] || 0 # since summer time switch it is null ...
  last_watts_value = watts_per_time_unit.last['v'] || 0 # since summer time switch it are last day produced watts

  sum = ((last_watts_value - first_watts_value) / 1000).round(1)
  return sum
end
