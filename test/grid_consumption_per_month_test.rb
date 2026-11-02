require_relative 'test_helper'
require_relative '../jobs/grid_consumption_per_day'
require_relative '../jobs/grid_consumption_per_month'
require 'fileutils'
require 'tmpdir'

class GridConsumptionPerMonthTest < Minitest::Test
  def setup
    @tmp_dir = Dir.mktmpdir
    ENV['STATE_FILE'] = File.join(@tmp_dir, 'state.json')
    # Zustand: Januar-Ende, Baselines 1000/500, Januar-Key
    $month_period_key               = '2024-01'
    $meter_count_supply_month_start = 1000.0
    $meter_count_feed_month_start   = 500.0
    $meter_count_supply_year_start  = 1000.0
    $meter_count_feed_year_start    = 500.0
    $kwh_supply_current_month = 0.0
    $kwh_feed_current_month   = 0.0
    $kwh_supply_last_month    = 0.0
    $kwh_feed_last_month      = 0.0
  end

  def teardown
    ENV.delete('STATE_FILE')
    FileUtils.remove_entry(@tmp_dir)
  end

  def test_rollover_due_when_period_key_differs
    assert_equal(true, rollover_due?('2024-01', '2024-02', 1200.0, 600.0))
  end

  def test_rollover_not_due_when_period_key_equal
    assert_equal(false, rollover_due?('2024-02', '2024-02', 1200.0, 600.0))
  end

  def test_rollover_not_due_with_invalid_reading
    assert_equal(false, rollover_due?('2024-01', '2024-02', 0, 600.0))
    assert_equal(false, rollover_due?('2024-01', '2024-02', 1200.0, 0))
  end

  def test_month_rollover_sets_baseline_and_last_month
    calculate_month_values(1200.0, 600.0, Time.new(2024, 1, 31, 23, 59, 0))
    calculate_month_values(1200.0, 600.0, Time.new(2024, 2, 1, 0, 0, 30))
    assert_equal('2024-02', $month_period_key)
    assert_equal(1200.0, $meter_count_supply_month_start)
    assert_equal(200.0, $kwh_supply_last_month)
    assert_equal(100.0, $kwh_feed_last_month)
  end

  def test_month_rollover_runs_only_once
    calculate_month_values(1200.0, 600.0, Time.new(2024, 1, 31, 23, 59, 0))
    calculate_month_values(1200.0, 600.0, Time.new(2024, 2, 1, 0, 0, 30))
    calculate_month_values(1200.5, 600.1, Time.new(2024, 2, 1, 0, 1, 30))
    calculate_month_values(1201.0, 600.2, Time.new(2024, 2, 1, 0, 2, 30))
    assert_equal(200.0, $kwh_supply_last_month)
    assert_equal(100.0, $kwh_feed_last_month)
    assert_equal(1.0, $kwh_supply_current_month)
  end

  def test_year_baseline_reset_only_in_january
    calculate_month_values(1200.0, 600.0, Time.new(2024, 2, 1, 0, 0, 30))
    assert_equal(1000.0, $meter_count_supply_year_start)

    $month_period_key = '2024-12'
    calculate_month_values(1500.0, 700.0, Time.new(2025, 1, 1, 0, 0, 30))
    assert_equal(1500.0, $meter_count_supply_year_start)
    assert_equal(700.0, $meter_count_feed_year_start)
  end
end
