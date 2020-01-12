require 'httparty'

# :first_in sets how long it takes before the job is first run. In this case, it is run immediately
SCHEDULER.every '2s', :first_in => 0 do |job|
  url_sma = 'https://192.168.178.98/dyn/getDashValues.json'
  response = HTTParty.post(url_sma, :verify => false)
  current_watts = response.parsed_response['result']['017A-B339126F']['6100_40263F00']['1'][0]['val']

  if current_watts.nil? || current_watts == 0
    current_watts = 0.0
  end

  send_event('wattmetersolar', { value: current_watts })
end
