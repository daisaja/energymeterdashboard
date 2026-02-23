require_relative 'meter_helper/grid_meter_client'
require_relative 'meter_helper/state_manager'

$kwh_supply_last_day          = 0.0
$kwh_supply_current_day       = 0.0
$meter_count_supply_yesterday = 0.0

$kwh_feed_last_day          = 0.0
$kwh_feed_current_day       = 0.0
$meter_count_feed_yesterday = 0.0

$day_state_initialized = false

if defined?(SCHEDULER)
  SCHEDULER.every '5s', :first_in => 0 do |job|
    grid_measurements = GridMeasurements.new()

    unless $day_state_initialized
      load_day_state(grid_measurements.grid_supply_total, grid_measurements.grid_feed_total)
      $day_state_initialized = true
    end

    calculate_deltas(grid_measurements.grid_supply_total, grid_measurements.grid_feed_total)

    send_event('meter_grid_supply_sum', { current: $kwh_supply_current_day, last: $kwh_supply_last_day })
    send_event('meter_grid_feed_sum',   { current: $kwh_feed_current_day,   last: $kwh_feed_last_day })
  end
end

# Load persisted baselines on startup. If the saved state is from today, restore it
# so current-day consumption continues correctly after a restart. Otherwise fall back
# to using the current meter reading as the new baseline (degraded mode: today's
# consumption will be counted from the restart moment, not from midnight).
def load_day_state(current_supply, current_feed)
  state = StateManager.load
  if state && state['day']['date'] == Date.today.to_s
    puts "[DayJob] Restoring day state from #{state['saved_at']}"
    $meter_count_supply_yesterday = state['day']['supply_baseline']
    $meter_count_feed_yesterday   = state['day']['feed_baseline']
    $kwh_supply_last_day          = state['day']['last_supply'].to_f
    $kwh_feed_last_day            = state['day']['last_feed'].to_f
  else
    puts "[DayJob] No valid day state — using current reading as baseline"
    $meter_count_supply_yesterday = current_supply
    $meter_count_feed_yesterday   = current_feed
  end
end

# Zählerstand um 00:00 Uhr:           580.7 (meter_count_feed_at_midnight)
# aktueller Zählerstand um 20:00 Uhr: 602.7 (meter_count_feed_now)
# delta:                               12.0 (kwh_feed_current_day)
# gestern:                              6.9 (kwh_feed_last_day)
def calculate_deltas(supply_now, feed_now)
  if is_new_day()
    $kwh_supply_last_day          = $kwh_supply_current_day
    $kwh_feed_last_day            = $kwh_feed_current_day
    $meter_count_supply_yesterday = supply_now
    $meter_count_feed_yesterday   = feed_now
    StateManager.save(day: current_day_state, month: current_month_state, year: current_year_state)
  end
  $kwh_supply_current_day = (supply_now - $meter_count_supply_yesterday).round(1)
  $kwh_feed_current_day   = (feed_now   - $meter_count_feed_yesterday).round(1)
end

def current_day_state
  {
    'date'            => Date.today.to_s,
    'supply_baseline' => $meter_count_supply_yesterday,
    'feed_baseline'   => $meter_count_feed_yesterday,
    'last_supply'     => $kwh_supply_last_day,
    'last_feed'       => $kwh_feed_last_day
  }
end
