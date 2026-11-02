require_relative 'test_helper'
require_relative '../jobs/grid_consumption_per_day'
require_relative '../jobs/grid_consumption_per_month'
require 'fileutils'
require 'tmpdir'

class GridConsumptionPerDayTest < Minitest::Test
  def setup
    @tmp_dir = Dir.mktmpdir
    ENV['STATE_FILE'] = File.join(@tmp_dir, 'state.json')
    $day_period_key               = '2024-01-15'
    $meter_count_supply_yesterday = 1000.0
    $meter_count_feed_yesterday   = 500.0
    $kwh_supply_current_day = 0.0
    $kwh_feed_current_day   = 0.0
    $kwh_supply_last_day    = 0.0
    $kwh_feed_last_day      = 0.0
  end

  def teardown
    ENV.delete('STATE_FILE')
    FileUtils.remove_entry(@tmp_dir)
  end

  def test_day_rollover_sets_baseline_and_last_day
    calculate_deltas(1010.0, 505.0, Time.new(2024, 1, 15, 23, 59, 58))
    calculate_deltas(1010.0, 505.0, Time.new(2024, 1, 16, 0, 0, 3))
    assert_equal('2024-01-16', $day_period_key)
    assert_equal(1010.0, $meter_count_supply_yesterday)
    assert_equal(10.0, $kwh_supply_last_day)
    assert_equal(5.0, $kwh_feed_last_day)
  end

  def test_day_rollover_runs_only_once
    calculate_deltas(1010.0, 505.0, Time.new(2024, 1, 15, 23, 59, 58))
    calculate_deltas(1010.0, 505.0, Time.new(2024, 1, 16, 0, 0, 3))
    calculate_deltas(1011.0, 505.5, Time.new(2024, 1, 16, 0, 0, 8))
    calculate_deltas(1012.0, 506.0, Time.new(2024, 1, 16, 0, 0, 13))
    assert_equal(10.0, $kwh_supply_last_day)
    assert_equal(5.0, $kwh_feed_last_day)
    assert_equal(2.0, $kwh_supply_current_day)
  end

  def test_day_rollover_skipped_with_invalid_reading_and_retried
    calculate_deltas(1010.0, 505.0, Time.new(2024, 1, 15, 23, 59, 58))
    calculate_deltas(0, 0, Time.new(2024, 1, 16, 0, 0, 3))
    assert_equal('2024-01-15', $day_period_key)
    assert_equal(1000.0, $meter_count_supply_yesterday)
    calculate_deltas(1010.0, 505.0, Time.new(2024, 1, 16, 0, 0, 8))
    assert_equal('2024-01-16', $day_period_key)
    assert_equal(10.0, $kwh_supply_last_day)
  end
end

class GridConsumptionPerDayLoadTest < Minitest::Test
  def setup
    @tmp_dir = Dir.mktmpdir
    ENV['STATE_FILE'] = File.join(@tmp_dir, 'state.json')
    $day_period_key = nil
    $meter_count_supply_yesterday = 0.0
    $meter_count_feed_yesterday   = 0.0
  end

  def teardown
    ENV.delete('STATE_FILE')
    FileUtils.remove_entry(@tmp_dir)
  end

  def test_load_day_state_does_not_adopt_zero_reading
    assert_equal(false, load_day_state(0, 0, Time.new(2024, 1, 15, 12, 0, 0)))
    assert_equal(0.0, $meter_count_supply_yesterday)
    assert_nil($day_period_key)
  end

  def test_load_day_state_adopts_valid_reading
    assert_equal(true, load_day_state(1000.0, 500.0, Time.new(2024, 1, 15, 12, 0, 0)))
    assert_equal(1000.0, $meter_count_supply_yesterday)
    assert_equal('2024-01-15', $day_period_key)
  end

  def test_load_day_state_ignores_persisted_zero_baseline
    StateManager.save(day: { 'date' => '2024-01-15', 'supply_baseline' => 0.0, 'feed_baseline' => 0.0,
                             'last_supply' => 1.0, 'last_feed' => 1.0 },
                      month: {}, year: {})
    assert_equal(true, load_day_state(1000.0, 500.0, Time.new(2024, 1, 15, 12, 0, 0)))
    assert_equal(1000.0, $meter_count_supply_yesterday)
  end
end
