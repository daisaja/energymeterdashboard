require_relative 'test_helper'
require_relative '../jobs/meter_helper/solar_meter_client'

class SolarMeterClientTest < Minitest::Test
  SOLAR_METER_URL = 'https://192.168.178.60/dyn/getDashValues.json'

  def setup
    WebMock.disable_net_connect!
  end

  def solar_response(power: 3500, serial: '017A-B339126F')
    { 'result' => { serial => { '6100_40263F00' => { '1' => [{ 'val' => power }] } } } }
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

  def test_solar_meter_client_fallback_serial
    stub_solar(solar_response(power: 2500, serial: '017A-xxxxx26F'))

    solar = SolarMeasurements.new
    assert_equal(2500, solar.solar_watts_current)
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
end
