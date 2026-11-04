require_relative 'meter_helper/grid_meter_client'
require_relative 'meter_helper/state_manager'
require_relative 'meter_helper/solar_meter_client'
require_relative 'meter_helper/opendtu_meter_client'
require_relative 'meter_helper/powerwall_client'

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

# Zusatzzaehler fuer Verbrauch/Eigenverbrauch: Monats-Baselines (kWh, nil = unbekannt)
# sma = SMA-Gesamtertrag, dtu = OpenDTU-Gesamtertrag, bat_out/bat_in = Batterie Entladung/Ladung
EXTRA_KEYS = %i[sma dtu bat_out bat_in].freeze
EXTRA_STATE_KEYS = { sma: 'sma_baseline', dtu: 'dtu_baseline',
                     bat_out: 'bat_out_baseline', bat_in: 'bat_in_baseline' }.freeze
$month_extra_baselines = {}

$kwh_consumption_current_month        = nil
$kwh_self_consumption_current_month   = nil
$self_consumption_ratio_current_month = nil
$autarky_current_month                = nil

if defined?(SCHEDULER)
  SCHEDULER.every '60s', :first_in => 0 do |job|
    grid_measurements = GridMeasurements.new()
    supply = grid_measurements.grid_supply_total
    feed   = grid_measurements.grid_feed_total
    extras = month_extras(SolarMeasurements.new, OpenDTUMeterClient.new, PowerwallClient.new)

    unless $month_state_initialized
      $month_state_initialized = load_month_state(supply, feed, Time.now, extras)
    end

    # Ohne gueltige Baseline (Zaehler nicht erreichbar) diesen Durchlauf auslassen
    next unless $month_state_initialized

    calculate_month_values(supply, feed, Time.now, extras)

    send_event('meter_grid_supply_month', { current: $kwh_supply_current_month, last: $kwh_supply_last_month })
    send_event('meter_grid_feed_month',   { current: $kwh_feed_current_month,   last: $kwh_feed_last_month })
    send_event('meter_grid_supply_year',  { value: $kwh_supply_current_year })
    send_event('meter_grid_feed_year',    { value: $kwh_feed_current_year })
  end
end

# Monatswechsel genau einmal pro Monat (Vergleich des Perioden-Keys statt Zeitfenster),
# danach aktuelle Monats-/Jahreswerte aus Zählerstandsdifferenzen berechnen.
def calculate_month_values(supply, feed, now = Time.now, extras = {})
  # Ungueltiger Zaehlerstand: Werte unveraendert lassen (sonst negative Differenzen)
  return unless supply.to_f > 0 && feed.to_f > 0

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
    # Zusatzzaehler: ungueltige Werte (nil/<=0) werden nicht Baseline, spaeter nachgeholt
    EXTRA_KEYS.each { |key| $month_extra_baselines[key] = valid_counter(extras[key]) }
    $month_period_key = current_key
    save_all_state(now)
  end

  # Fehlende Baselines (z.B. Geraet war beim Start/Monatswechsel offline) nachholen
  missing = EXTRA_KEYS.select { |key| $month_extra_baselines[key].nil? && valid_counter(extras[key]) }
  missing.each { |key| $month_extra_baselines[key] = extras[key] }
  save_all_state(now) unless missing.empty?

  $kwh_supply_current_month = (supply - $meter_count_supply_month_start).round(1)
  $kwh_feed_current_month   = (feed   - $meter_count_feed_month_start).round(1)
  $kwh_supply_current_year  = (supply - $meter_count_supply_year_start).round(1)
  $kwh_feed_current_year    = (feed   - $meter_count_feed_year_start).round(1)

  calculate_consumption_values(extras)
end

# Zaehlerstand nur gueltig, wenn > 0 (nil sonst)
def valid_counter(value)
  value.to_f > 0 ? value : nil
end

# Monatsdelta eines Zusatzzaehlers; nil bei fehlender Baseline/Messung oder rueckwaerts laufendem Zaehler
def extra_delta(key, extras)
  base = $month_extra_baselines[key]
  now_value = valid_counter(extras[key])
  return nil if base.nil? || now_value.nil? || now_value < base

  now_value - base
end

# Verbrauch, Eigenverbrauch, Quote und Autarkie des Monats aus Deltas (nil bei fehlenden Eingaengen)
def calculate_consumption_values(extras)
  supply = $kwh_supply_current_month
  feed   = $kwh_feed_current_month
  sma, dtu = extra_delta(:sma, extras), extra_delta(:dtu, extras)
  solar = sma && dtu ? sma + dtu : nil

  consumption = month_consumption(supply, solar, feed, extra_delta(:bat_out, extras), extra_delta(:bat_in, extras))
  self_consumption = month_self_consumption(solar, feed)

  $kwh_consumption_current_month        = consumption&.round(1)
  $kwh_self_consumption_current_month   = self_consumption&.round(1)
  $self_consumption_ratio_current_month = self_consumption_ratio(self_consumption, solar)&.round(1)
  $autarky_current_month                = autarky(consumption, supply)&.round(1)
end

# Gesamtzaehler der Geraete (kWh) fuer den Monatsjob; nil, wenn ein Geraet nichts liefert
def month_extras(solar, opendtu, powerwall)
  { sma: solar.solar_kwh_total, dtu: opendtu.yield_total_kwh,
    bat_out: powerwall.battery_exported_kwh, bat_in: powerwall.battery_imported_kwh }
end

# Load persisted month/year baselines on startup.
# Gibt true zurueck, wenn gueltige Baselines gesetzt wurden. Ein Zaehlerstand <= 0 wird nie
# als Baseline uebernommen (-> false, Retry im naechsten Durchlauf); persistierte
# 0-Baselines werden verworfen.
def load_month_state(current_supply, current_feed, now = Time.now, extras = {})
  state = StateManager.load
  valid_reading = current_supply.to_f > 0 && current_feed.to_f > 0

  month = state && state['month']
  month_ok = month && month['year_month'] == now.strftime('%Y-%m') &&
             month['supply_baseline'].to_f > 0 && month['feed_baseline'].to_f > 0
  year = state && state['year']
  year_ok = year && year['year'] == now.year.to_s &&
            year['supply_baseline'].to_f > 0 && year['feed_baseline'].to_f > 0

  return false unless (month_ok && year_ok) || valid_reading

  if month_ok
    puts "[MonthJob] Restoring month state from #{state['saved_at']}"
    $month_period_key               = month['year_month']
    $meter_count_supply_month_start = month['supply_baseline'].to_f
    $meter_count_feed_month_start   = month['feed_baseline'].to_f
    $kwh_supply_last_month          = month['last_supply'].to_f
    $kwh_feed_last_month            = month['last_feed'].to_f
  else
    puts "[MonthJob] No valid month state — using current reading as baseline"
    $month_period_key               = now.strftime('%Y-%m')
    $meter_count_supply_month_start = current_supply
    $meter_count_feed_month_start   = current_feed
  end

  if year_ok
    puts "[MonthJob] Restoring year state from #{state['saved_at']}"
    $meter_count_supply_year_start = year['supply_baseline'].to_f
    $meter_count_feed_year_start   = year['feed_baseline'].to_f
  else
    puts "[MonthJob] No valid year state — using current reading as baseline"
    $meter_count_supply_year_start = current_supply
    $meter_count_feed_year_start   = current_feed
  end
  # Zusatzzaehler: persistierte Baseline (> 0) uebernehmen, sonst aktuellen gueltigen Wert;
  # fehlen die Keys (aelterer State), werden nur diese neu initialisiert.
  EXTRA_KEYS.each do |key|
    persisted = month_ok ? valid_counter(month[EXTRA_STATE_KEYS[key]]) : nil
    $month_extra_baselines[key] = persisted ? persisted.to_f : valid_counter(extras[key])
  end
  # Fallback-Baseline sofort persistieren (ersetzt ggf. 0-Baselines in state.json);
  # save_all_state schreibt erst, wenn auch der andere Job initialisiert ist.
  $month_state_initialized = true
  save_all_state(now)
  true
end

def current_month_state(now = Time.now)
  {
    'year_month'      => $month_period_key || now.strftime('%Y-%m'),
    'supply_baseline' => $meter_count_supply_month_start,
    'feed_baseline'   => $meter_count_feed_month_start,
    'last_supply'     => $kwh_supply_last_month,
    'last_feed'       => $kwh_feed_last_month
  }.merge(EXTRA_STATE_KEYS.to_h { |key, state_key| [state_key, $month_extra_baselines[key]] })
end

def current_year_state(now = Time.now)
  {
    'year'            => now.year.to_s,
    'supply_baseline' => $meter_count_supply_year_start,
    'feed_baseline'   => $meter_count_feed_year_start
  }
end

# --- Verbrauch und Eigenverbrauch aus Monatsdeltas (kWh). Fehlt ein Eingang -> nil. ---

# Verbrauch = Bezug + Solar - Einspeisung + Batterie-Entladung - Batterie-Ladung
def month_consumption(supply, solar, feed, battery_out, battery_in)
  return nil if [supply, solar, feed, battery_out, battery_in].any?(&:nil?)

  supply + solar - feed + battery_out - battery_in
end

# Eigenverbrauch = Solar - Einspeisung
def month_self_consumption(solar, feed)
  return nil if solar.nil? || feed.nil?

  solar - feed
end

# Eigenverbrauchsquote in % (nil ohne Solarertrag)
def self_consumption_ratio(self_consumption, solar)
  return nil if self_consumption.nil? || solar.nil? || solar <= 0

  self_consumption / solar * 100.0
end

# Autarkie in % = (Verbrauch - Bezug) / Verbrauch (nil ohne Verbrauch)
def autarky(consumption, supply)
  return nil if consumption.nil? || supply.nil? || consumption <= 0

  (consumption - supply) / consumption * 100.0
end
