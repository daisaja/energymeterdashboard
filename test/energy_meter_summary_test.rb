require_relative 'test_helper'
require 'ostruct'
require_relative '../jobs/energy_meter_summary'

class EnergyMeterSummaryTest < Minitest::Test
  # Werte aus dem Live-Event-Stream vom 2026-11-02

  def test_meter_reading_without_decimals
    assert_equal('2241 kWh', format_meter_value(2241.1665, 'kWh', 0))
  end

  def test_meter_reading_rounds_half_up
    assert_equal('1249 kWh', format_meter_value(1248.5, 'kWh', 0))
  end

  def test_month_value_one_decimal_with_comma
    assert_equal('1248,2 kWh', format_meter_value(1248.2253, 'kWh', 1))
  end

  def test_month_value_keeps_trailing_zero
    assert_equal('713,0 kWh', format_meter_value(713.0, 'kWh', 1))
  end

  def test_watts_without_decimals
    # 1.512 kW aus dem Grid-Client, im Job * 1000 → 1511.9999999999998
    assert_equal('1512 W', format_meter_value(1.512 * 1000, 'W', 0))
  end

  def test_integer_input
    assert_equal('0 W', format_meter_value(0, 'W', 0))
  end

  def test_nil_value_shows_placeholder
    # Ausgefallener Client darf das Widget nicht crashen
    assert_equal('– kWh', format_meter_value(nil, 'kWh', 1))
  end

  # --- overview_items ---

  GLOBALS = %i[$month_state_initialized $kwh_supply_current_month $kwh_feed_current_month
               $kwh_supply_current_year $kwh_feed_current_year $vzlogger_warning].freeze

  def setup
    @saved_globals = GLOBALS.to_h { |g| [g, (eval("defined?(#{g})") ? eval(g.to_s) : :undefined)] }
    GLOBALS.each { |g| eval("#{g} = nil") }
    @grid = OpenStruct.new(grid_supply_total: 2241.1665, grid_feed_total: 1248.5,
                           grid_supply_current: 1.512, grid_feed_current: 0.0)
    @solar = OpenStruct.new(solar_watts_current: 321.4)
    @heating = OpenStruct.new(heating_per_month: 713.0)
  end

  def teardown
    @saved_globals.each do |g, v|
      v == :undefined ? eval("#{g} = nil") : eval("#{g} = #{v.inspect}")
    end
  end

  def set_month_globals
    $month_state_initialized = true
    $kwh_supply_current_month = 123.456
    $kwh_feed_current_month = 45.678
    $kwh_supply_current_year = 1234.4
    $kwh_feed_current_year = 567.4
  end

  def values
    overview_items(@grid, @solar, @heating).map { |i| i[:value] }
  end

  def test_overview_labels_in_order
    labels = overview_items(@grid, @solar, @heating).map { |i| i[:label] }
    assert_equal(['Netzbezug (Monat)', 'Einspeisung (Monat)', 'Heizung (Monat)', 'Verbrauch (Monat)',
                  'Bezug (Jahr)', 'Einspeisung (Jahr)', 'Zählerstand Bezug', 'Zählerstand Einspeisung',
                  'Bezug (jetzt)', 'Einspeisung (jetzt)', 'Solar (jetzt)'], labels)
  end

  def test_overview_values_when_initialized
    set_month_globals
    assert_equal(['123,5 kWh', '45,7 kWh', '713,0 kWh', '– kWh', '1234 kWh', '567 kWh',
                  '2241 kWh', '1249 kWh', '1512 W', '0 W', '321 W'], values)
  end

  def test_overview_grid_rows_placeholder_when_not_initialized
    set_month_globals
    $month_state_initialized = false
    v = values
    assert_equal(['– kWh'] * 2, v[0, 2])
    assert_equal(['– kWh'] * 2, v[4, 2])
    assert_equal('713,0 kWh', v[2])
  end

  def test_overview_grid_rows_placeholder_when_flag_nil
    set_month_globals
    # nil-Flag wie bei noch nicht gesetztem Global
    $month_state_initialized = nil
    assert_equal('– kWh', values[0])
  end

  def test_overview_without_warning_has_no_warning_row
    $vzlogger_warning = nil
    refute_includes(overview_items(@grid, @solar, @heating).map { |i| i[:label] }, '⚠ Warnung')
  end

  def test_overview_with_warning_prepends_row
    $vzlogger_warning = 'vzlogger offline seit 14 min'
    items = overview_items(@grid, @solar, @heating)
    assert_equal({ label: '⚠ Warnung', value: 'vzlogger offline seit 14 min' }, items.first)
    assert_equal('Netzbezug (Monat)', items[1][:label])
    assert_equal(12, items.size)
  end
end
