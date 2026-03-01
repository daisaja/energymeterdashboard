require_relative 'test_helper'
require 'ostruct'
require_relative '../jobs/energyflow'

class EnergyflowTest < Minitest::Test
  def test_house_consumption_solar_only
    # Solar produces 2400W, nothing else active
    payload = build_energyflow_payload(
      OpenStruct.new(grid_supply_current: 0.0, grid_feed_current: 0.0),
      OpenStruct.new(solar_watts_current: 2400),
      OpenStruct.new(power_watts: 0.0, soc_percent: 80),
      OpenStruct.new(heating_watts_current: 0)
    )
    assert_equal 2400, payload[:house_w]
    assert_equal 2400, payload[:solar_w]
    assert_equal 0,    payload[:grid_w]
  end

  def test_house_consumption_grid_supply
    # 1kW from grid, 0 solar
    payload = build_energyflow_payload(
      OpenStruct.new(grid_supply_current: 1.0, grid_feed_current: 0.0),
      OpenStruct.new(solar_watts_current: 0),
      OpenStruct.new(power_watts: 0.0, soc_percent: 50),
      OpenStruct.new(heating_watts_current: 0)
    )
    assert_equal 1000, payload[:house_w]
    assert_equal 1000, payload[:grid_w]   # positive = supply (Bezug)
  end

  def test_grid_w_negative_when_feeding_in
    # Solar produces 3kW, house uses 1kW → feed 2kW
    payload = build_energyflow_payload(
      OpenStruct.new(grid_supply_current: 0.0, grid_feed_current: 2.0),
      OpenStruct.new(solar_watts_current: 3000),
      OpenStruct.new(power_watts: 0.0, soc_percent: 100),
      OpenStruct.new(heating_watts_current: 0)
    )
    assert_equal(-2000, payload[:grid_w])   # negative = Einspeisung
    assert_equal 1000,  payload[:house_w]   # 3000 - 2000 = 1000W house
  end

  def test_battery_discharge_adds_to_house
    # Battery discharges 500W (power_watts = -500)
    payload = build_energyflow_payload(
      OpenStruct.new(grid_supply_current: 0.0, grid_feed_current: 0.0),
      OpenStruct.new(solar_watts_current: 1000),
      OpenStruct.new(power_watts: -500.0, soc_percent: 60),
      OpenStruct.new(heating_watts_current: 0)
    )
    assert_equal(-500, payload[:battery_w])
    assert_equal 1500, payload[:house_w]    # 1000 solar + 500 discharge
  end

  def test_battery_charging_does_not_add_to_house
    # Battery charges 800W (power_watts = +800) — charging takes power FROM house, not adds
    payload = build_energyflow_payload(
      OpenStruct.new(grid_supply_current: 0.0, grid_feed_current: 0.0),
      OpenStruct.new(solar_watts_current: 3000),
      OpenStruct.new(power_watts: 800.0, soc_percent: 40),
      OpenStruct.new(heating_watts_current: 0)
    )
    assert_equal 800,  payload[:battery_w]
    assert_equal 3000, payload[:house_w]   # battery_discharge = 0, so house = solar only
  end

  def test_heatpump_w_from_heating_client
    payload = build_energyflow_payload(
      OpenStruct.new(grid_supply_current: 0.5, grid_feed_current: 0.0),
      OpenStruct.new(solar_watts_current: 0),
      OpenStruct.new(power_watts: 0.0, soc_percent: 70),
      OpenStruct.new(heating_watts_current: 600)
    )
    assert_equal 600, payload[:heatpump_w]
  end

  def test_battery_soc_included
    payload = build_energyflow_payload(
      OpenStruct.new(grid_supply_current: 0.0, grid_feed_current: 0.0),
      OpenStruct.new(solar_watts_current: 0),
      OpenStruct.new(power_watts: 0.0, soc_percent: 78),
      OpenStruct.new(heating_watts_current: 0)
    )
    assert_equal 78, payload[:battery_soc]
  end
end
