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
      .to_return(status: 200, body: { 'tm' => "#{Date.today.strftime('%Y-%m')}-01T00:00:00", 'val' => [10, 15, 20, 25] }.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })
    stub_request(:get, "#{HEATING_BASE_URL}/V?d=0&f=j")
      .to_return(status: 200, body: { 'tm' => "#{Date.today}T00:00:00", 'val' => [100, 200, 300, 400] }.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })
    stub_request(:get, "#{HEATING_BASE_URL}/V?d=1&f=j")
      .to_return(status: 200, body: { 'tm' => "#{Date.today - 1}T00:00:00", 'val' => [100, 200, 300, 400] }.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })
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

  def stub_youless(month_vals:, day_vals:, month_tm: nil, day_tm: nil, last_day_tm: nil)
    today = Date.today
    json = { headers: { CONTENT_TYPE_JSON => APPLICATION_JSON } }
    stub_request(:get, "#{HEATING_BASE_URL}/a?f=j")
      .to_return(json.merge(status: 200, body: { 'pwr' => 971 }.to_json))
    stub_request(:get, %r{#{Regexp.escape(HEATING_BASE_URL)}/V\?f=j&m=\d+})
      .to_return(json.merge(status: 200, body: { 'tm' => month_tm || "#{today.strftime('%Y-%m')}-01T00:00:00", 'val' => month_vals }.to_json))
    stub_request(:get, "#{HEATING_BASE_URL}/V?d=0&f=j")
      .to_return(json.merge(status: 200, body: { 'tm' => day_tm || "#{today}T00:00:00", 'val' => day_vals }.to_json))
    stub_request(:get, "#{HEATING_BASE_URL}/V?d=1&f=j")
      .to_return(json.merge(status: 200, body: { 'tm' => last_day_tm || "#{today - 1}T00:00:00", 'val' => day_vals }.to_json))
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

  # --- Validierung von tm (Geräteuhr kann falsch gehen / Vorjahresdaten liefern) ---

  def test_month_from_previous_year_is_nil
    # Gleicher Monat, aber Vorjahr: m=11 liefert November 2025, heute ist 2026-11
    stub_youless(month_vals: [' 45,000'], day_vals: [100], month_tm: '2025-11-01T00:00:00')
    heating = HeatingMeasurements.new(Date.new(2026, 11, 4))
    assert_nil(heating.heating_per_month)
  end

  def test_month_with_matching_year_month_is_used
    stub_youless(month_vals: [' 45,000', '  8,100'], day_vals: [100], month_tm: '2026-11-01T00:00:00')
    heating = HeatingMeasurements.new(Date.new(2026, 11, 4))
    assert_in_delta(53.1, heating.heating_per_month, 0.0001)
  end

  def test_month_with_missing_tm_is_nil
    stub_youless(month_vals: [' 45,000'], day_vals: [100], month_tm: 'kaputt')
    heating = HeatingMeasurements.new(Date.new(2026, 11, 4))
    assert_nil(heating.heating_per_month)
  end

  def test_stale_day_values_are_nil
    # Geräteuhr hängt auf 2026-09-23, heute ist 2026-11-04
    stub_youless(month_vals: [1], day_vals: ['  400'],
                 day_tm: '2026-09-23T00:00:00', last_day_tm: '2026-09-22T00:00:00')
    heating = HeatingMeasurements.new(Date.new(2026, 11, 4))
    assert_nil(heating.heating_kwh_current_day)
    assert_nil(heating.heating_kwh_last_day)
  end

  def test_current_and_last_day_with_matching_tm
    stub_youless(month_vals: [1], day_vals: ['  400', ' 1020'],
                 day_tm: '2026-11-04T00:00:00', last_day_tm: '2026-11-03T00:00:00')
    heating = HeatingMeasurements.new(Date.new(2026, 11, 4))
    assert_equal(1.4, heating.heating_kwh_current_day)
    assert_equal(1.4, heating.heating_kwh_last_day)
  end

  def test_last_day_with_todays_tm_is_nil
    stub_youless(month_vals: [1], day_vals: ['  400'],
                 day_tm: '2026-11-04T00:00:00', last_day_tm: '2026-11-04T00:00:00')
    heating = HeatingMeasurements.new(Date.new(2026, 11, 4))
    assert_equal(0.4, heating.heating_kwh_current_day)
    assert_nil(heating.heating_kwh_last_day)
  end

  def test_nil_values_are_not_replaced_by_last_values_when_data_reachable
    # Veraltete Daten (nil) dürfen nicht durch alte Cache-Werte kaschiert werden
    stub_youless(month_vals: [1], day_vals: ['  400'], month_tm: '2025-11-01T00:00:00')
    HeatingMeasurements.new(Date.new(2026, 11, 4))
    heating = HeatingMeasurements.new(Date.new(2026, 11, 4))
    assert_nil(heating.heating_per_month)
    assert_equal(971, heating.heating_watts_current)
  end

  def test_stale_data_then_connection_error_falls_back_to_zero
    HeatingMeasurements.class_variable_set(:@@last_values, {})
    stub_youless(month_vals: [1], day_vals: ['  400'], month_tm: '2025-11-01T00:00:00')
    HeatingMeasurements.new(Date.new(2026, 11, 4))
    WebMock.reset!
    stub_request(:get, "#{HEATING_BASE_URL}/a?f=j").to_raise(Errno::ECONNREFUSED)
    heating = HeatingMeasurements.new(Date.new(2026, 11, 4))
    assert_equal(971, heating.heating_watts_current)
    assert_equal(0.0, heating.heating_per_month)
  end

  def test_day_event_payload_replaces_nil_with_zero
    # Number-Widget zeigt bei nil "NaN%" – daher 0.0 senden
    stub_youless(month_vals: [1], day_vals: ['  400'],
                 day_tm: '2026-09-23T00:00:00', last_day_tm: '2026-09-22T00:00:00')
    heating = HeatingMeasurements.new(Date.new(2026, 11, 4))
    assert_equal({ current: 0.0, last: 0.0 }, heating.day_event_payload)
  end

  def test_day_event_payload_with_values
    stub_youless(month_vals: [1], day_vals: ['  400', ' 1020'],
                 day_tm: '2026-11-04T00:00:00', last_day_tm: '2026-11-03T00:00:00')
    heating = HeatingMeasurements.new(Date.new(2026, 11, 4))
    assert_equal({ current: 1.4, last: 1.4 }, heating.day_event_payload)
  end
end
