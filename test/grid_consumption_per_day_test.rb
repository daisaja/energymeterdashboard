require_relative 'test_helper'
require 'fileutils'
require 'tmpdir'
require 'date'
require_relative '../jobs/meter_helper/state_manager'
require_relative '../jobs/grid_consumption_per_day'
require_relative '../jobs/grid_consumption_per_month'

class GridConsumptionPerDayTest < Minitest::Test
  def setup
    @tmp_dir    = Dir.mktmpdir
    @state_file = File.join(@tmp_dir, 'state.json')
    ENV['STATE_FILE'] = @state_file

    $kwh_supply_last_day          = 0.0
    $kwh_supply_current_day       = 0.0
    $meter_count_supply_yesterday = 0.0
    $kwh_feed_last_day            = 0.0
    $kwh_feed_current_day         = 0.0
    $meter_count_feed_yesterday   = 0.0
  end

  def teardown
    ENV.delete('STATE_FILE')
    FileUtils.remove_entry(@tmp_dir)
  end

  # --- calculate_deltas ---

  def test_calculate_deltas_computes_supply_delta
    $meter_count_supply_yesterday = 500.0
    $meter_count_feed_yesterday   = 100.0
    stub_method(:is_new_day, false) { calculate_deltas(510.0, 103.5) }
    assert_equal 10.0, $kwh_supply_current_day
    assert_equal  3.5, $kwh_feed_current_day
  end

  def test_calculate_deltas_rounds_to_one_decimal
    $meter_count_supply_yesterday = 100.0
    $meter_count_feed_yesterday   = 100.0
    stub_method(:is_new_day, false) { calculate_deltas(100.123, 100.456) }
    assert_equal 0.1, $kwh_supply_current_day
    assert_equal 0.5, $kwh_feed_current_day
  end

  def test_calculate_deltas_rollover_promotes_current_to_last
    $kwh_supply_current_day = 15.3
    $kwh_feed_current_day   =  4.7
    stub_method(:is_new_day, true) do
      stub_on(StateManager, :save, nil) { calculate_deltas(600.0, 110.0) }
    end
    assert_equal 15.3, $kwh_supply_last_day
    assert_equal  4.7, $kwh_feed_last_day
  end

  def test_calculate_deltas_rollover_sets_new_baselines
    stub_method(:is_new_day, true) do
      stub_on(StateManager, :save, nil) { calculate_deltas(600.0, 110.0) }
    end
    assert_equal 600.0, $meter_count_supply_yesterday
    assert_equal 110.0, $meter_count_feed_yesterday
  end

  def test_calculate_deltas_rollover_current_day_is_zero_after_reset
    stub_method(:is_new_day, true) do
      stub_on(StateManager, :save, nil) { calculate_deltas(600.0, 110.0) }
    end
    assert_equal 0.0, $kwh_supply_current_day
    assert_equal 0.0, $kwh_feed_current_day
  end

  def test_calculate_deltas_rollover_calls_state_manager_save
    save_called = false
    stub_method(:is_new_day, true) do
      stub_on(StateManager, :save, ->(**_) { save_called = true }) do
        calculate_deltas(600.0, 110.0)
      end
    end
    assert save_called, 'StateManager.save should be called on day rollover'
  end

  def test_calculate_deltas_no_rollover_does_not_save_state
    save_called = false
    stub_method(:is_new_day, false) do
      stub_on(StateManager, :save, ->(**_) { save_called = true }) do
        calculate_deltas(510.0, 102.0)
      end
    end
    refute save_called, 'StateManager.save should not be called mid-day'
  end

  # --- load_day_state ---

  def test_load_day_state_restores_todays_baselines
    state = {
      'saved_at' => Time.now.iso8601,
      'day'   => { 'date' => Date.today.to_s, 'supply_baseline' => 1234.5,
                   'feed_baseline' => 567.8, 'last_supply' => 10.0, 'last_feed' => 2.5 },
      'month' => { 'year_month' => Time.now.strftime('%Y-%m') },
      'year'  => { 'year' => Time.now.year.to_s }
    }
    stub_on(StateManager, :load, state) { load_day_state(999.0, 888.0) }
    assert_equal 1234.5, $meter_count_supply_yesterday
    assert_equal  567.8, $meter_count_feed_yesterday
    assert_equal   10.0, $kwh_supply_last_day
    assert_equal    2.5, $kwh_feed_last_day
  end

  def test_load_day_state_stale_date_uses_current_reading
    state = {
      'saved_at' => (Time.now - 86400).iso8601,
      'day'   => { 'date' => (Date.today - 1).to_s, 'supply_baseline' => 100.0,
                   'feed_baseline' => 50.0, 'last_supply' => 5.0, 'last_feed' => 1.0 },
      'month' => { 'year_month' => Time.now.strftime('%Y-%m') },
      'year'  => { 'year' => Time.now.year.to_s }
    }
    stub_on(StateManager, :load, state) { load_day_state(500.0, 100.0) }
    assert_equal 500.0, $meter_count_supply_yesterday
    assert_equal 100.0, $meter_count_feed_yesterday
  end

  def test_load_day_state_nil_state_uses_current_reading
    stub_on(StateManager, :load, nil) { load_day_state(500.0, 100.0) }
    assert_equal 500.0, $meter_count_supply_yesterday
    assert_equal 100.0, $meter_count_feed_yesterday
  end
end
