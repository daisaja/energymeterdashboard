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
    stub_request(:get, %r{#{Regexp.escape(HEATING_BASE_URL)}/V\?f=j&m=\d+})
      .to_return(status: 200, body: { 'val' => [10, 15, 20, 25] }.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })
    stub_request(:get, "#{HEATING_BASE_URL}/V?d=0&f=j")
      .to_return(status: 200, body: { 'val' => [100, 200, 300, 400] }.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })
    stub_request(:get, "#{HEATING_BASE_URL}/V?d=1&f=j")
      .to_return(status: 200, body: { 'val' => [100, 200, 300, 400] }.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })
  end

  def stub_heating_error(error)
    stub_request(:get, "#{HEATING_BASE_URL}/a?f=j").to_raise(error)
    stub_request(:get, %r{#{Regexp.escape(HEATING_BASE_URL)}/V\?f=j&m=\d+}).to_raise(error)
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

  # --- YouLess-Zahlenformat: Dezimalkomma, führende Leerzeichen, null ---

  def stub_youless(month_vals:, day_vals:, tm: nil)
    json = { headers: { CONTENT_TYPE_JSON => APPLICATION_JSON } }
    stub_request(:get, "#{HEATING_BASE_URL}/a?f=j")
      .to_return(json.merge(status: 200, body: { 'pwr' => 971 }.to_json))
    stub_request(:get, %r{#{Regexp.escape(HEATING_BASE_URL)}/V\?f=j&m=\d+})
      .to_return(json.merge(status: 200, body: { 'val' => month_vals }.to_json))
    stub_request(:get, "#{HEATING_BASE_URL}/V?d=0&f=j")
      .to_return(json.merge(status: 200, body: { 'val' => day_vals }.to_json))
    stub_request(:get, "#{HEATING_BASE_URL}/V?d=1&f=j")
      .to_return(json.merge(status: 200, body: { 'val' => day_vals }.to_json))
  end

  def test_parse_youless_number_with_decimal_comma
    heating = HeatingMeasurements.allocate
    assert_in_delta(8.1, heating.parse_youless_number(' 8,100'), 0.0001)
    assert_in_delta(45.0, heating.parse_youless_number(' 45,000'), 0.0001)
    assert_equal(400.0, heating.parse_youless_number('  400'))
  end

  def test_parse_youless_number_nil_and_empty
    heating = HeatingMeasurements.allocate
    assert_nil(heating.parse_youless_number(nil))
    assert_nil(heating.parse_youless_number(''))
    assert_nil(heating.parse_youless_number('   '))
  end

  def test_month_sum_with_decimal_comma_and_null
    stub_youless(month_vals: [' 45,000', ' 43,000', '  8,100', nil], day_vals: [100])
    heating = HeatingMeasurements.new
    assert_in_delta(96.1, heating.heating_per_month, 0.0001)
  end

  def test_day_sum_with_padded_watt_strings
    stub_youless(month_vals: [1], day_vals: ['  400', ' 1020', nil])
    heating = HeatingMeasurements.new
    assert_equal(1.4, heating.heating_kwh_current_day)
  end

  def test_day_sum_with_decimal_comma
    stub_youless(month_vals: [1], day_vals: ['  400,5', ' 1020', nil])
    heating = HeatingMeasurements.new
    assert_equal(1.4, heating.heating_kwh_current_day)
  end
end
