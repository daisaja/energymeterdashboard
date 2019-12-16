# :first_in sets how long it takes before the job is first run. In this case, it is run immediately
#SCHEDULER.every '1m', :first_in => 0 do |job|
SCHEDULER.every '1s', :first_in => 0 do |job|
  kwh_day = 0
  kwh_last_day = 0
  send_event('wattmetersolar_sum', { current: kwh_day, last: kwh_last_day})
end
