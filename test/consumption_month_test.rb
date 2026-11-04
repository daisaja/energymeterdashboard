require_relative 'test_helper'
require_relative '../jobs/grid_consumption_per_day'
require_relative '../jobs/grid_consumption_per_month'

# Reine Formeln fuer Monatsverbrauch und Eigenverbrauchskennzahlen
class ConsumptionFormulasTest < Minitest::Test
  def test_consumption_without_battery
    # 300 Bezug + 200 Solar - 50 Einspeisung
    assert_in_delta(450.0, month_consumption(300.0, 200.0, 50.0, 0.0, 0.0), 0.001)
  end

  def test_consumption_with_battery_discharge_and_charge
    # + 40 Entladung - 25 Ladung
    assert_in_delta(465.0, month_consumption(300.0, 200.0, 50.0, 40.0, 25.0), 0.001)
  end

  def test_consumption_with_zero_solar
    assert_in_delta(300.0, month_consumption(300.0, 0.0, 0.0, 0.0, 0.0), 0.001)
  end

  def test_consumption_nil_when_any_input_missing
    refute_nil(month_consumption(300.0, 200.0, 50.0, 40.0, 25.0))
    5.times do |i|
      args = [300.0, 200.0, 50.0, 40.0, 25.0]
      args[i] = nil
      assert_nil(month_consumption(*args), "Eingang #{i} fehlt")
    end
  end

  def test_self_consumption
    assert_in_delta(150.0, month_self_consumption(200.0, 50.0), 0.001)
    assert_nil(month_self_consumption(nil, 50.0))
    assert_nil(month_self_consumption(200.0, nil))
  end

  def test_self_consumption_ratio_percent
    assert_in_delta(75.0, self_consumption_ratio(150.0, 200.0), 0.001)
  end

  def test_self_consumption_ratio_nil_for_zero_solar_or_missing
    assert_nil(self_consumption_ratio(0.0, 0.0))
    assert_nil(self_consumption_ratio(nil, 200.0))
    assert_nil(self_consumption_ratio(150.0, nil))
  end

  def test_autarky_percent
    # Verbrauch 450, Bezug 300 -> 150 aus eigener Erzeugung
    assert_in_delta(33.333, autarky(450.0, 300.0), 0.001)
    assert_in_delta(0.0, autarky(300.0, 300.0), 0.001)
  end

  def test_autarky_nil_for_zero_consumption_or_missing
    assert_nil(autarky(0.0, 0.0))
    assert_nil(autarky(nil, 300.0))
    assert_nil(autarky(450.0, nil))
  end
end
