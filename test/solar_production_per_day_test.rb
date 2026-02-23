require_relative 'test_helper'
require 'date'
require_relative '../jobs/solar_production_per_day'

class SolarProductionPerDayTest < Minitest::Test

  # Build a time-series array of { 't' => unix_ts, 'v' => cumulative_wh }
  # spanning yesterday and today, so tests are independent of the current date.
  def today_start_ts
    t = Time.now
    Time.new(t.year, t.month, t.day).to_i
  end

  # --- kwh_current_day ---

  def test_kwh_current_day_normal
    ts = today_start_ts
    data = [
      { 't' => ts - 7200, 'v' => 4500 },  # yesterday
      { 't' => ts - 3600, 'v' => 4800 },  # yesterday
      { 't' => ts + 100,  'v' => 5000 },  # today's first entry  ← baseline
      { 't' => ts + 1800, 'v' => 5900 },  # today mid
      { 't' => ts + 3600, 'v' => 6500 },  # today's last entry
    ]
    # (6500 - 5000) / 1000 = 1.5
    assert_equal 1.5, kwh_current_day(data)
  end

  def test_kwh_current_day_single_today_entry
    ts = today_start_ts
    data = [
      { 't' => ts - 3600, 'v' => 4800 },  # yesterday
      { 't' => ts + 100,  'v' => 5200 },  # only today's entry (first = last)
    ]
    # (5200 - 5200) / 1000 = 0.0
    assert_equal 0.0, kwh_current_day(data)
  end

  def test_kwh_current_day_no_entries_from_today
    # All entries have timestamps before today — first_watts_value stays 0
    ts = today_start_ts
    data = [
      { 't' => ts - 7200, 'v' => 3000 },
      { 't' => ts - 3600, 'v' => 4000 },
    ]
    # (4000 - 0) / 1000 = 4.0
    assert_equal 4.0, kwh_current_day(data)
  end

  def test_kwh_current_day_rounds_to_one_decimal
    ts = today_start_ts
    data = [
      { 't' => ts + 100, 'v' => 5000 },
      { 't' => ts + 200, 'v' => 6234 },
    ]
    # (6234 - 5000) / 1000 = 1.234 → rounds to 1.2
    assert_equal 1.2, kwh_current_day(data)
  end

  # --- kwh_last_day ---

  def test_kwh_last_day_normal
    data = [
      { 't' => 0, 'v' => 1000 },
      { 't' => 1, 'v' => 5000 },
    ]
    # (5000 - 1000) / 1000 = 4.0
    assert_equal 4.0, kwh_last_day(data)
  end

  def test_kwh_last_day_nil_first_value_falls_back_to_zero
    # DST edge case documented in source: first 'v' can be nil
    data = [
      { 't' => 0, 'v' => nil  },
      { 't' => 1, 'v' => 5000 },
    ]
    # (5000 - 0) / 1000 = 5.0
    assert_equal 5.0, kwh_last_day(data)
  end

  def test_kwh_last_day_nil_last_value_falls_back_to_zero
    data = [
      { 't' => 0, 'v' => 1000 },
      { 't' => 1, 'v' => nil  },
    ]
    # (0 - 1000) / 1000 = -1.0
    assert_equal(-1.0, kwh_last_day(data))
  end

  def test_kwh_last_day_both_nil_returns_zero
    data = [
      { 't' => 0, 'v' => nil },
      { 't' => 1, 'v' => nil },
    ]
    assert_equal 0.0, kwh_last_day(data)
  end

  def test_kwh_last_day_rounds_to_one_decimal
    data = [
      { 't' => 0, 'v' => 1000 },
      { 't' => 1, 'v' => 4567 },
    ]
    # (4567 - 1000) / 1000 = 3.567 → rounds to 3.6
    assert_equal 3.6, kwh_last_day(data)
  end
end
