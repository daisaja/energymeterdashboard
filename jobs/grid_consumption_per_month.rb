require_relative 'meter_helper/grid_meter_client'

$kwh_supply_current_month = 0.0
$kwh_supply_last_month    = 0.0
$meter_count_supply_month_start = 0.0

$kwh_feed_current_month = 0.0
$kwh_feed_last_month    = 0.0
$meter_count_feed_month_start = 0.0

$kwh_supply_current_year = 0.0
$kwh_feed_current_year   = 0.0
$meter_count_supply_year_start = 0.0
$meter_count_feed_year_start   = 0.0

SCHEDULER.every '60s', :first_in => 0 do |job|
  grid_measurements = GridMeasurements.new()
  supply = grid_measurements.grid_supply_total
  feed   = grid_measurements.grid_feed_total

  # Init beim ersten Lauf: Zählerstand als Startpunkt merken
  if $meter_count_supply_month_start == 0.0
    $meter_count_supply_month_start = supply
    $meter_count_feed_month_start   = feed
    $meter_count_supply_year_start  = supply
    $meter_count_feed_year_start    = feed
  end

  if is_new_month()
    $meter_count_supply_month_start = supply
    $kwh_supply_last_month = $kwh_supply_current_month
    $meter_count_feed_month_start = feed
    $kwh_feed_last_month = $kwh_feed_current_month
    # Jahreswechsel: Januar = neues Jahr
    if Time.now.month == 1
      $meter_count_supply_year_start = supply
      $meter_count_feed_year_start   = feed
    end
  end

  $kwh_supply_current_month = (supply - $meter_count_supply_month_start).round(1)
  $kwh_feed_current_month   = (feed   - $meter_count_feed_month_start).round(1)
  $kwh_supply_current_year  = (supply - $meter_count_supply_year_start).round(1)
  $kwh_feed_current_year    = (feed   - $meter_count_feed_year_start).round(1)

  send_event('meter_grid_supply_month', { current: $kwh_supply_current_month, last: $kwh_supply_last_month })
  send_event('meter_grid_feed_month',   { current: $kwh_feed_current_month,   last: $kwh_feed_last_month })
  send_event('meter_grid_supply_year',  { value: $kwh_supply_current_year })
  send_event('meter_grid_feed_year',    { value: $kwh_feed_current_year })
end
