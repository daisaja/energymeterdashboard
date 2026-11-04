require_relative 'test_helper'
require_relative '../jobs/grid_consumption_per_day'
require_relative '../jobs/grid_consumption_per_month'
require 'fileutils'
require 'tmpdir'
require 'ostruct'

# Baselines/Deltas der Zusatzzaehler (SMA, OpenDTU, Batterie) im Monatsjob
class ConsumptionMonthJobTest < Minitest::Test
  JAN = Time.new(2024, 1, 31, 23, 59, 0)
  FEB = Time.new(2024, 2, 1, 0, 0, 30)

  def extras(sma: 5000.0, dtu: 100.0, bat_out: 800.0, bat_in: 900.0)
    { sma: sma, dtu: dtu, bat_out: bat_out, bat_in: bat_in }
  end

  def setup
    @tmp_dir = Dir.mktmpdir
    ENV['STATE_FILE'] = File.join(@tmp_dir, 'state.json')
    $day_state_initialized   = true
    $month_state_initialized = true
    $month_period_key               = '2024-01'
    $meter_count_supply_month_start = 1000.0
    $meter_count_feed_month_start   = 500.0
    $meter_count_supply_year_start  = 1000.0
    $meter_count_feed_year_start    = 500.0
    $kwh_supply_current_month = 0.0
    $kwh_feed_current_month   = 0.0
    $kwh_supply_last_month    = 0.0
    $kwh_feed_last_month      = 0.0
    $month_extra_baselines = extras
    $kwh_consumption_current_month = nil
    $kwh_self_consumption_current_month = nil
    $self_consumption_ratio_current_month = nil
    $autarky_current_month = nil
  end

  def teardown
    ENV.delete('STATE_FILE')
    FileUtils.remove_entry(@tmp_dir)
  end

  def test_month_globals_from_deltas
    # Bezug +300, Einspeisung +50, SMA +150, DTU +50 (Solar 200), Entladung +40, Ladung +25
    calculate_month_values(1300.0, 550.0, JAN,
                           extras(sma: 5150.0, dtu: 150.0, bat_out: 840.0, bat_in: 925.0))
    assert_in_delta(465.0, $kwh_consumption_current_month, 0.001)
    assert_in_delta(150.0, $kwh_self_consumption_current_month, 0.001)
    assert_in_delta(75.0,  $self_consumption_ratio_current_month, 0.001)
    assert_in_delta(35.5, $autarky_current_month, 0.05)   # auf 1 Stelle gerundet
  end

  def test_zero_solar_gives_nil_ratio_but_consumption
    calculate_month_values(1300.0, 500.0, JAN, extras)
    assert_in_delta(300.0, $kwh_consumption_current_month, 0.001)
    assert_nil($self_consumption_ratio_current_month)
    assert_in_delta(0.0, $autarky_current_month, 0.001)
  end

  def test_missing_input_makes_derived_values_nil
    calculate_month_values(1300.0, 550.0, JAN, extras(bat_out: nil))
    assert_nil($kwh_consumption_current_month)
    assert_nil($autarky_current_month)
  end

  def test_counter_going_backwards_gives_nil
    calculate_month_values(1300.0, 550.0, JAN, extras(sma: 4000.0))
    assert_nil($kwh_consumption_current_month)
  end

  def test_nil_or_zero_reading_never_becomes_baseline
    $month_extra_baselines = extras(bat_out: nil)
    calculate_month_values(1300.0, 550.0, JAN, extras(bat_out: nil))
    assert_nil($month_extra_baselines[:bat_out])
    calculate_month_values(1300.0, 550.0, JAN, extras(bat_out: 0))
    assert_nil($month_extra_baselines[:bat_out])
    calculate_month_values(1300.0, 550.0, JAN, extras(bat_out: 810.0))
    assert_equal(810.0, $month_extra_baselines[:bat_out])
  end

  def test_late_initialised_baseline_is_persisted
    $month_extra_baselines = extras(dtu: nil)
    calculate_month_values(1300.0, 550.0, JAN, extras(dtu: 120.0))
    assert_equal(120.0, StateManager.load['month']['dtu_baseline'])
  end

  def test_rollover_sets_extra_baselines_exactly_once
    calculate_month_values(1200.0, 600.0, JAN, extras)
    calculate_month_values(1250.0, 620.0, FEB, extras(sma: 5300.0, dtu: 160.0, bat_out: 850.0, bat_in: 950.0))
    assert_equal({ sma: 5300.0, dtu: 160.0, bat_out: 850.0, bat_in: 950.0 }, $month_extra_baselines)
    calculate_month_values(1260.0, 625.0, Time.new(2024, 2, 1, 0, 1, 30),
                           extras(sma: 5310.0, dtu: 161.0, bat_out: 851.0, bat_in: 951.0))
    assert_equal(5300.0, $month_extra_baselines[:sma])
    assert_in_delta(10.0, $kwh_supply_current_month, 0.001)
  end

  def test_rollover_with_invalid_extra_leaves_baseline_nil_until_valid
    calculate_month_values(1200.0, 600.0, JAN, extras)
    calculate_month_values(1250.0, 620.0, FEB, extras(bat_in: nil))
    assert_nil($month_extra_baselines[:bat_in])
    assert_equal(5000.0, $month_extra_baselines[:sma])
  end

  def test_state_contains_extra_baselines
    calculate_month_values(1200.0, 600.0, JAN, extras)
    calculate_month_values(1250.0, 620.0, FEB, extras)
    month = StateManager.load['month']
    assert_equal(5000.0, month['sma_baseline'])
    assert_equal(100.0,  month['dtu_baseline'])
    assert_equal(800.0,  month['bat_out_baseline'])
    assert_equal(900.0,  month['bat_in_baseline'])
  end

  def test_load_restores_persisted_extra_baselines
    StateManager.save(day: {},
                      month: { 'year_month' => '2024-02', 'supply_baseline' => 1000.0, 'feed_baseline' => 500.0,
                               'last_supply' => 0.0, 'last_feed' => 0.0,
                               'sma_baseline' => 4000.0, 'dtu_baseline' => 90.0,
                               'bat_out_baseline' => 700.0, 'bat_in_baseline' => 800.0 },
                      year: { 'year' => '2024', 'supply_baseline' => 900.0, 'feed_baseline' => 300.0 })
    load_month_state(1100.0, 550.0, Time.new(2024, 2, 10, 12, 0, 0), extras)
    assert_equal({ sma: 4000.0, dtu: 90.0, bat_out: 700.0, bat_in: 800.0 }, $month_extra_baselines)
  end

  def test_load_old_state_without_extra_keys_keeps_grid_baselines
    StateManager.save(day: {},
                      month: { 'year_month' => '2024-02', 'supply_baseline' => 1000.0, 'feed_baseline' => 500.0,
                               'last_supply' => 80.0, 'last_feed' => 20.0 },
                      year: { 'year' => '2024', 'supply_baseline' => 900.0, 'feed_baseline' => 300.0 })
    $month_extra_baselines = {}
    load_month_state(1100.0, 550.0, Time.new(2024, 2, 10, 12, 0, 0), extras)
    assert_equal(1000.0, $meter_count_supply_month_start)
    assert_equal(500.0, $meter_count_feed_month_start)
    assert_equal(80.0, $kwh_supply_last_month)
    assert_equal({ sma: 5000.0, dtu: 100.0, bat_out: 800.0, bat_in: 900.0 }, $month_extra_baselines)
  end

  def test_load_does_not_adopt_invalid_extra_readings_or_zero_baselines
    StateManager.save(day: {},
                      month: { 'year_month' => '2024-02', 'supply_baseline' => 1000.0, 'feed_baseline' => 500.0,
                               'last_supply' => 0.0, 'last_feed' => 0.0, 'sma_baseline' => 0.0 },
                      year: { 'year' => '2024', 'supply_baseline' => 900.0, 'feed_baseline' => 300.0 })
    $month_extra_baselines = {}
    load_month_state(1100.0, 550.0, Time.new(2024, 2, 10, 12, 0, 0), extras(sma: 5000.0, dtu: nil, bat_out: 0))
    assert_equal(5000.0, $month_extra_baselines[:sma])
    assert_nil($month_extra_baselines[:dtu])
    assert_nil($month_extra_baselines[:bat_out])
  end

  def test_month_extras_from_clients
    sma = OpenStruct.new(solar_kwh_total: 5000.0)
    dtu = OpenStruct.new(yield_total_kwh: 100.0)
    pw  = OpenStruct.new(battery_exported_kwh: 800.0, battery_imported_kwh: 900.0)
    assert_equal({ sma: 5000.0, dtu: 100.0, bat_out: 800.0, bat_in: 900.0 }, month_extras(sma, dtu, pw))
  end
end
