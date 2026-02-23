require_relative 'test_helper'
require_relative '../jobs/solar_watts'

class SolarWattsTest < Minitest::Test
  def setup
    $solar_peak_of_the_day = 0
  end

  # --- set_solar_current_peak ---

  def test_set_solar_current_peak_updates_when_higher
    $solar_peak_of_the_day = 1000
    set_solar_current_peak(1500)
    assert_equal 1500, $solar_peak_of_the_day
  end

  def test_set_solar_current_peak_no_update_when_lower
    $solar_peak_of_the_day = 1000
    set_solar_current_peak(500)
    assert_equal 1000, $solar_peak_of_the_day
  end

  def test_set_solar_current_peak_no_update_when_equal
    $solar_peak_of_the_day = 1000
    set_solar_current_peak(1000)
    assert_equal 1000, $solar_peak_of_the_day
  end

  def test_set_solar_current_peak_starts_from_zero
    set_solar_current_peak(800)
    assert_equal 800, $solar_peak_of_the_day
  end

  # --- reset_solar_peak_meter ---

  def test_reset_solar_peak_meter_resets_on_new_day
    $solar_peak_of_the_day = 5000
    stub_method(:is_new_day, true) { reset_solar_peak_meter }
    assert_equal 0, $solar_peak_of_the_day
  end

  def test_reset_solar_peak_meter_keeps_value_same_day
    $solar_peak_of_the_day = 5000
    stub_method(:is_new_day, false) { reset_solar_peak_meter }
    assert_equal 5000, $solar_peak_of_the_day
  end
end
