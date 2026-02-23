require_relative 'test_helper'
require 'fileutils'
require 'tmpdir'
require 'date'
require_relative '../jobs/meter_helper/state_manager'
require_relative '../jobs/grid_consumption_per_day'
require_relative '../jobs/grid_consumption_per_month'

class GridConsumptionPerMonthTest < Minitest::Test
  def setup
    @tmp_dir    = Dir.mktmpdir
    @state_file = File.join(@tmp_dir, 'state.json')
    ENV['STATE_FILE'] = @state_file

    $kwh_supply_current_month       = 0.0
    $kwh_supply_last_month          = 0.0
    $meter_count_supply_month_start = 0.0
    $kwh_feed_current_month         = 0.0
    $kwh_feed_last_month            = 0.0
    $meter_count_feed_month_start   = 0.0
    $kwh_supply_current_year        = 0.0
    $kwh_feed_current_year          = 0.0
    $meter_count_supply_year_start  = 0.0
    $meter_count_feed_year_start    = 0.0
  end

  def teardown
    ENV.delete('STATE_FILE')
    FileUtils.remove_entry(@tmp_dir)
  end

  def full_state(month_ym: Time.now.strftime('%Y-%m'),
                 year_str: Time.now.year.to_s,
                 month_supply: 1100.0, month_feed: 500.0,
                 month_last_supply: 80.0, month_last_feed: 20.0,
                 year_supply: 900.0, year_feed: 300.0)
    {
      'saved_at' => Time.now.iso8601,
      'day'   => { 'date' => Date.today.to_s, 'supply_baseline' => 0.0,
                   'feed_baseline' => 0.0, 'last_supply' => 0.0, 'last_feed' => 0.0 },
      'month' => { 'year_month'      => month_ym,
                   'supply_baseline' => month_supply,
                   'feed_baseline'   => month_feed,
                   'last_supply'     => month_last_supply,
                   'last_feed'       => month_last_feed },
      'year'  => { 'year'            => year_str,
                   'supply_baseline' => year_supply,
                   'feed_baseline'   => year_feed }
    }
  end

  # --- load_month_state: month section ---

  def test_load_month_state_restores_current_month_baselines
    stub_on(StateManager, :load, full_state) { load_month_state(999.0, 888.0) }
    assert_equal 1100.0, $meter_count_supply_month_start
    assert_equal  500.0, $meter_count_feed_month_start
    assert_equal   80.0, $kwh_supply_last_month
    assert_equal   20.0, $kwh_feed_last_month
  end

  def test_load_month_state_stale_month_uses_current_reading
    last_month = (Date.today << 1).strftime('%Y-%m')
    stub_on(StateManager, :load, full_state(month_ym: last_month)) do
      load_month_state(500.0, 100.0)
    end
    assert_equal 500.0, $meter_count_supply_month_start
    assert_equal 100.0, $meter_count_feed_month_start
  end

  # --- load_month_state: year section ---

  def test_load_month_state_restores_current_year_baselines
    stub_on(StateManager, :load, full_state) { load_month_state(999.0, 888.0) }
    assert_equal 900.0, $meter_count_supply_year_start
    assert_equal 300.0, $meter_count_feed_year_start
  end

  def test_load_month_state_stale_year_uses_current_reading
    last_year = (Time.now.year - 1).to_s
    stub_on(StateManager, :load, full_state(year_str: last_year)) do
      load_month_state(500.0, 100.0)
    end
    assert_equal 500.0, $meter_count_supply_year_start
    assert_equal 100.0, $meter_count_feed_year_start
  end

  def test_load_month_state_nil_state_uses_current_reading
    stub_on(StateManager, :load, nil) { load_month_state(500.0, 100.0) }
    assert_equal 500.0, $meter_count_supply_month_start
    assert_equal 100.0, $meter_count_feed_month_start
    assert_equal 500.0, $meter_count_supply_year_start
    assert_equal 100.0, $meter_count_feed_year_start
  end

  # --- current_month_state and current_year_state helpers ---

  def test_current_month_state_contains_expected_keys
    result = current_month_state
    assert result.key?('year_month')
    assert result.key?('supply_baseline')
    assert result.key?('feed_baseline')
    assert result.key?('last_supply')
    assert result.key?('last_feed')
    assert_equal Time.now.strftime('%Y-%m'), result['year_month']
  end

  def test_current_year_state_contains_expected_keys
    result = current_year_state
    assert result.key?('year')
    assert result.key?('supply_baseline')
    assert result.key?('feed_baseline')
    assert_equal Time.now.year.to_s, result['year']
  end
end
