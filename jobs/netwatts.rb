require 'httparty'

# :first_in sets how long it takes before the job is first run. In this case, it is run immediately
SCHEDULER.every '1s', :first_in => 0 do |job|

  # Augenblickverbrauch
  url_overview = 'http://192.168.178.10/a?f=j'
  response = HTTParty.get(url_overview)
  send_event('wattmeternet',   { value: response.parsed_response['pwr'] })

end
