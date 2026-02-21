require_relative 'meter_helper/powerwall_client'

SCHEDULER.every '5s', :first_in => 0 do |job|
  client = PowerwallClient.new

  send_event('powerwall_soc',    { value: client.soc_percent })
  send_event('powerwall_power',  { current: client.power_watts })
  send_event('powerwall_stored', { current: client.stored_kwh })
end
