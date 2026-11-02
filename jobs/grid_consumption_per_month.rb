require_relative 'meter_helper/grid_meter_client'
require_relative 'meter_helper/state_manager'

$kwh_supply_current_month       = 0.0
$kwh_supply_last_month          = 0.0
$meter_count_supply_month_start = 0.0

$kwh_feed_current_month       = 0.0
$kwh_feed_last_month          = 0.0
$meter_count_feed_month_start = 0.0

$kwh_supply_current_year       = 0.0
$kwh_feed_current_year         = 0.0
$meter_count_supply_year_start = 0.0
$meter_count_feed_year_start   = 0.0

$month_state_initialized = false
$month_period_key         = nil

if defined?(SCHEDULER)
  SCHEDULER.every '60s', :first_in => 0 do |job|
    grid_measurements = GridMeasurements.new()
    supply = grid_measurements.grid_supply_total
    feed   = grid_measurements.grid_feed_total

    unless $month_state_initialized
      load_month_state(supply, feed)
      $month_state_initialized = true
    end

    calculate_month_values(supply, feed)

    send_event('meter_grid_supply_month', { current: $kwh_supply_current_month, last: $kwh_supply_last_month })
    send_event('meter_grid_feed_month',   { current: $kwh_feed_current_month,   last: $kwh_feed_last_month })
    send_event('meter_grid_supply_year',  { value: $kwh_supply_current_year })
    send_event('meter_grid_feed_year',    { value: $kwh_feed_current_year })
  end
end

# Monatswechsel genau einmal pro Monat (Vergleich des Perioden-Keys statt Zeitfenster),
# danach aktuelle Monats-/Jahreswerte aus Zählerstandsdifferenzen berechnen.
def calculate_month_values(supply, feed, now = Time.now)
  current_key = now.strftime('%Y-%m')
  if rollover_due?($month_period_key, current_key, supply, feed)
    $kwh_supply_last_month          = $kwh_supply_current_month
    $kwh_feed_last_month            = $kwh_feed_current_month
    $meter_count_supply_month_start = supply
    $meter_count_feed_month_start   = feed
    if now.month == 1
      $meter_count_supply_year_start = supply
      $meter_count_feed_year_start   = feed
    end
    $month_period_key = current_key
    StateManager.save(day: current_day_state, month: current_month_state(now), year: current_year_state(now))
  end

  $kwh_supply_current_month = (supply - $meter_count_supply_month_start).round(1)
  $kwh_feed_current_month   = (feed   - $meter_count_feed_month_start).round(1)
  $kwh_supply_current_year  = (supply - $meter_count_supply_year_start).round(1)
  $kwh_feed_current_year    = (feed   - $meter_count_feed_year_start).round(1)
end

# Load persisted month/year baselines on startup.
def load_month_state(current_supply, current_feed)
  state = StateManager.load

  if state && state['month']['year_month'] == Time.now.strftime('%Y-%m')
    puts "[MonthJob] Restoring month state from #{state['saved_at']}"
    $month_period_key               = state['month']['year_month']
    $meter_count_supply_month_start = state['month']['supply_baseline'].to_f
    $meter_count_feed_month_start   = state['month']['feed_baseline'].to_f
    $kwh_supply_last_month          = state['month']['last_supply'].to_f
    $kwh_feed_last_month            = state['month']['last_feed'].to_f
  else
    puts "[MonthJob] No valid month state — using current reading as baseline"
    $month_period_key               = Time.now.strftime('%Y-%m')
    $meter_count_supply_month_start = current_supply
    $meter_count_feed_month_start   = current_feed
  end

  if state && state['year']['year'] == Time.now.year.to_s
    puts "[MonthJob] Restoring year state from #{state['saved_at']}"
    $meter_count_supply_year_start = state['year']['supply_baseline'].to_f
    $meter_count_feed_year_start   = state['year']['feed_baseline'].to_f
  else
    puts "[MonthJob] No valid year state — using current reading as baseline"
    $meter_count_supply_year_start = current_supply
    $meter_count_feed_year_start   = current_feed
  end
end

def current_month_state(now = Time.now)
  {
    'year_month'      => $month_period_key || now.strftime('%Y-%m'),
    'supply_baseline' => $meter_count_supply_month_start,
    'feed_baseline'   => $meter_count_feed_month_start,
    'last_supply'     => $kwh_supply_last_month,
    'last_feed'       => $kwh_feed_last_month
  }
end

def current_year_state(now = Time.now)
  {
    'year'            => now.year.to_s,
    'supply_baseline' => $meter_count_supply_year_start,
    'feed_baseline'   => $meter_count_feed_year_start
  }
end
