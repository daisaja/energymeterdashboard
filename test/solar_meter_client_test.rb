require_relative 'test_helper'
require_relative '../jobs/meter_helper/solar_meter_client'

class SolarMeterClientTest < Minitest::Test
  SOLAR_METER_URL = 'https://192.168.178.60/dyn/getDashValues.json'

  def setup
    WebMock.disable_net_connect!
  end

  def solar_response(power: 3500, serial: '017A-xxxxx26F', total_wh: 42_165_864)
    values = { '6100_40263F00' => { '1' => [{ 'val' => power }] } }
    # Gesamtertrag (Wh), Schluessel wie vom echten Wechselrichter geliefert
    values['6400_00260100'] = { '1' => [{ 'val' => total_wh }] } unless total_wh == :missing
    { 'result' => { serial => values } }
  end

  def stub_solar(body)
    stub_request(:post, SOLAR_METER_URL)
      .to_return(status: 200, body: body.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })
  end

  def test_solar_meter_client
    stub_solar(solar_response)

    solar = SolarMeasurements.new
    assert_equal(3500, solar.solar_watts_current)
    assert_equal(0.0,  solar.solar_watts_per_month)
  end

  def test_solar_meter_client_unknown_device_key
    stub_solar(solar_response(power: 2500, serial: '017A-UNKNOWN0'))

    solar = SolarMeasurements.new
    assert_equal(-1, solar.solar_watts_current)
  end

  def test_solar_meter_client_nil_value
    stub_solar(solar_response(power: nil))

    solar = SolarMeasurements.new
    assert_equal(0.0, solar.solar_watts_current)
  end

  def test_solar_meter_client_error_handling
    SolarMeasurements.class_variable_set(:@@last_values, {})
    stub_request(:post, SOLAR_METER_URL).to_raise(Errno::ECONNREFUSED)

    solar = SolarMeasurements.new
    assert_equal(0.0, solar.solar_watts_current)
    assert_equal(0.0, solar.solar_watts_per_month)
  end

  def test_solar_meter_client_host_unreachable
    SolarMeasurements.class_variable_set(:@@last_values, {})
    stub_request(:post, SOLAR_METER_URL).to_raise(Errno::EHOSTUNREACH)

    solar = SolarMeasurements.new
    assert_equal(0.0, solar.solar_watts_current)
    assert_equal(0.0, solar.solar_watts_per_month)
  end

  def test_solar_meter_client_keeps_last_values_on_error
    stub_solar(solar_response)

    solar = SolarMeasurements.new
    assert_equal(3500, solar.solar_watts_current)

    WebMock.reset!
    stub_request(:post, SOLAR_METER_URL).to_raise(Errno::ECONNREFUSED)

    solar2 = SolarMeasurements.new
    assert_equal(3500, solar2.solar_watts_current)
    assert_equal(0.0,  solar2.solar_watts_per_month)
  end

  def test_solar_meter_client_total_yield_in_kwh
    stub_solar(solar_response(total_wh: 42_165_864))

    assert_equal(42_165.864, SolarMeasurements.new.solar_kwh_total)
  end

  def test_solar_meter_client_total_yield_nil_when_missing
    SolarMeasurements.class_variable_set(:@@last_values, {})
    stub_solar(solar_response(total_wh: :missing))

    assert_nil(SolarMeasurements.new.solar_kwh_total)
  end

  def test_solar_meter_client_total_yield_nil_value
    SolarMeasurements.class_variable_set(:@@last_values, {})
    stub_solar(solar_response(total_wh: nil))

    assert_nil(SolarMeasurements.new.solar_kwh_total)
  end

  def test_solar_meter_client_total_yield_kept_on_error
    stub_solar(solar_response(total_wh: 1_000_000))
    SolarMeasurements.new

    WebMock.reset!
    stub_request(:post, SOLAR_METER_URL).to_raise(Errno::ECONNREFUSED)
    assert_equal(1000.0, SolarMeasurements.new.solar_kwh_total)
  end
end
