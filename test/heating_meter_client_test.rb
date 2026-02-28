require_relative 'test_helper'
require_relative '../jobs/meter_helper/heating_meter_client'

class HeatingMeterClientTest < Minitest::Test
  HEATING_BASE_URL = 'http://192.168.178.50'

  def setup
    WebMock.disable_net_connect!
  end

  def stub_heating_success
    stub_request(:get, "#{HEATING_BASE_URL}/a?f=j")
      .to_return(status: 200, body: { 'pwr' => 1500 }.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })
    stub_request(:get, %r{#{Regexp.escape(HEATING_BASE_URL)}/V\?\?f=j&m=\d+})
      .to_return(status: 200, body: { 'val' => [10, 15, 20, 25] }.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })
    stub_request(:get, "#{HEATING_BASE_URL}/V?d=0&f=j")
      .to_return(status: 200, body: { 'val' => [100, 200, 300, 400] }.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })
    stub_request(:get, "#{HEATING_BASE_URL}/V?d=1&f=j")
      .to_return(status: 200, body: { 'val' => [100, 200, 300, 400] }.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })
  end

  def stub_heating_error(error)
    stub_request(:get, "#{HEATING_BASE_URL}/a?f=j").to_raise(error)
    stub_request(:get, %r{#{Regexp.escape(HEATING_BASE_URL)}/V\?\?f=j&m=\d+}).to_raise(error)
    stub_request(:get, "#{HEATING_BASE_URL}/V?d=0&f=j").to_raise(error)
    stub_request(:get, "#{HEATING_BASE_URL}/V?d=1&f=j").to_raise(error)
  end

  def test_heating_meter_client
    stub_heating_success

    heating = HeatingMeasurements.new
    assert_equal(1500, heating.heating_watts_current)
    assert_equal(70.0, heating.heating_per_month)
    assert_equal(1.0,  heating.heating_kwh_current_day)
    assert_equal(1.0,  heating.heating_kwh_last_day)
  end

  def test_heating_meter_client_error_handling
    HeatingMeasurements.class_variable_set(:@@last_values, {})
    stub_heating_error(Errno::ECONNREFUSED)

    heating = HeatingMeasurements.new
    assert_equal(0.0, heating.heating_watts_current)
    assert_equal(0.0, heating.heating_per_month)
    assert_equal(0.0, heating.heating_kwh_current_day)
    assert_equal(0.0, heating.heating_kwh_last_day)
  end

  def test_heating_meter_client_host_unreachable
    HeatingMeasurements.class_variable_set(:@@last_values, {})
    stub_request(:get, "#{HEATING_BASE_URL}/a?f=j").to_raise(Errno::EHOSTUNREACH)

    heating = HeatingMeasurements.new
    assert_equal(0.0, heating.heating_watts_current)
    assert_equal(0.0, heating.heating_per_month)
    assert_equal(0.0, heating.heating_kwh_current_day)
    assert_equal(0.0, heating.heating_kwh_last_day)
  end

  def test_heating_meter_client_keeps_last_values_on_error
    stub_heating_success

    heating = HeatingMeasurements.new
    assert_equal(1500, heating.heating_watts_current)

    WebMock.reset!
    stub_request(:get, "#{HEATING_BASE_URL}/a?f=j").to_raise(Errno::ECONNREFUSED)

    heating2 = HeatingMeasurements.new
    assert_equal(1500, heating2.heating_watts_current)
    assert_equal(70.0, heating2.heating_per_month)
    assert_equal(1.0,  heating2.heating_kwh_current_day)
    assert_equal(1.0,  heating2.heating_kwh_last_day)
  end

  def test_socket_error_falls_back_to_last_values
    # SocketError (DNS failure) was previously not caught — job would fail entirely
    HeatingMeasurements.class_variable_set(:@@last_values, {})
    stub_request(:get, "#{HEATING_BASE_URL}/a?f=j").to_raise(SocketError)

    heating = HeatingMeasurements.new
    assert_equal(0.0, heating.heating_watts_current)
  end

  def test_current_watts_preserved_when_secondary_requests_fail
    # Request 1 (current power) succeeds, requests 2-4 (monthly/daily) fail.
    # heating_watts_current must still reflect the freshly-read value so the
    # energyflow job can send an event with the correct heatpump wattage.
    HeatingMeasurements.class_variable_set(:@@last_values, { heating_watts_current: 0 })
    stub_request(:get, "#{HEATING_BASE_URL}/a?f=j")
      .to_return(status: 200, body: { 'pwr' => 1500 }.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })
    stub_request(:get, %r{#{Regexp.escape(HEATING_BASE_URL)}/V}).to_raise(SocketError)

    heating = HeatingMeasurements.new
    assert_equal(1500, heating.heating_watts_current)
  end
end
