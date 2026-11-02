require_relative 'test_helper'
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
end
