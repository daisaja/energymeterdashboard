require 'httparty'
require_relative 'meter_helper/grid_meter_client'

# TODO Needs to be intialized on first job run with current values or with stored values
$kwh_supply_last_day = 0.0
$kwh_supply_current_day = 0.0
$meter_count_supply_yesterday = 0.0

$kwh_feed_last_day = 0.0
$kwh_feed_current_day = 0.0
$meter_count_feed_yesterday = 0.0

SCHEDULER.every '5s', :first_in => 0 do |job|
  # Zählerstand Bezug
  uuid_grid_supply_count = '007aeef0-4a01-11ea-8773-6bda87ed0b9a' # OBIS: 255-255::1.8.0*255
  # Zählerstand Einspeisung
  uuid_grid_feet_count = 'e564e6e0-4a00-11ea-af71-a55e127a0bfc' # OBIS: 255-255::2.8.0*255

  url_overview = 'http://192.168.178.102:8081/'
  response = HTTParty.get(url_overview)

  grid_supply = find_current_grid_kwh(uuid_grid_supply_count, response.parsed_response['data'])
  grid_feed = find_current_grid_kwh(uuid_grid_feet_count, response.parsed_response['data'])

  init_job_after_start(grid_supply, grid_feed)

  $kwh_supply_current_day = calculate_delta_supply(grid_supply)
  $kwh_feed_current_day = calculate_delta_feed(grid_feed)

  send_event('meter_grid_supply_sum',   { current: $kwh_supply_current_day, last: $kwh_supply_last_day })
  send_event('meter_grid_feed_sum',   { current: $kwh_feed_current_day, last: $kwh_feed_last_day })
end

# Init values after restart of service - little hack to count kWhs after start from zero instaed of showing meter count in total
def init_job_after_start(grid_supply, grid_feed)
  if ($meter_count_supply_yesterday == 0.0 and $meter_count_feed_yesterday == 0.0)
    $meter_count_supply_yesterday = grid_supply
    $meter_count_feed_yesterday = grid_feed
  end
end

# Zählerstand um 00:00 Uhr:           580.7 (meter_count_feed_at_midnight)
# aktueller Zählerstand um 20:00 Uhr: 602.7 (meter_count_feed_now)
# delta:                               12.0 (kwh_feed_current_day)
# gestern:                              6.9 (kwh_feed_last_day)

# Bezug
def calculate_delta_supply(meter_count_supply_now)
  # Wenn ein neuer Tag anbricht merke dir den Zählerstand vom Begin des Tages und speichere den Vorbrauch vom Vortag
  if is_new_day()
    $meter_count_supply_yesterday = meter_count_supply_now
    $kwh_supply_last_day = $kwh_supply_current_day
  end
  # Berechne verbrauchte kWh anhand der Differenz der Zählerstände
  return (meter_count_supply_now - $meter_count_supply_yesterday).round(1)
end

# Einspeisung
def calculate_delta_feed(meter_count_feed_now)
  # Wenn ein neuer Tag anbricht merke dir den Zählerstand vom Begin des Tages und speichere den Vorbrauch vom Vortag
  if is_new_day()
    puts 'new day'
    $meter_count_feed_yesterday = meter_count_feed_now
    $kwh_feed_last_day = $kwh_feed_current_day
    puts "meter meter_count_feed_now #{meter_count_feed_now}"
    puts "meter meter_count_feed_yesterday #{$meter_count_feed_yesterday}"
    puts "meter kwh_feed_last_day #{$kwh_feed_last_day}"
    puts "meter kwh_feed_current_day #{$kwh_feed_current_day}"
  end
  # Berechne verbrauchte kWh anhand der Differenz der Zählerstände
  return (meter_count_feed_now - $meter_count_feed_yesterday).round(1)
end
